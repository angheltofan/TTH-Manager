import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../auth/providers/auth_providers.dart';
import '../../children/providers/children_providers.dart';
import '../data/workshops_repository.dart';
import '../domain/series_enrolled_child.dart';
import '../domain/workshop_detail_row.dart';
import '../providers/enrollment_providers.dart';
import '../providers/workshops_providers.dart';
import 'widgets/workshop_children_list.dart';
import 'widgets/workshop_header_card.dart';

// ─────────────────────────────────────────────────────────────────────────────

class WorkshopDetailsPage extends ConsumerStatefulWidget {
  const WorkshopDetailsPage({super.key, required this.workshopId});

  final String workshopId;

  @override
  ConsumerState<WorkshopDetailsPage> createState() =>
      _WorkshopDetailsPageState();
}

class _WorkshopDetailsPageState extends ConsumerState<WorkshopDetailsPage> {
  // Tracks which childIds are currently being saved
  final Set<String> _marking = {};
  bool _markingAll = false;
  String? _listenedSeriesId;

  // Realtime for `attendance` and `workshop_enrollments` is handled centrally
  // by appRealtimeProvider. For enrollments, the central provider invalidates
  // seriesEnrolledChildrenProvider(seriesId) — but it cannot also invalidate
  // workshopDetailsProvider(workshopId) because the payload only carries
  // series_id. We bridge that gap below with a ref.listen on the enrolled
  // children provider; when it refreshes, we invalidate the details view.

  /// Admin-only **permanent** delete. Two paths:
  ///
  ///   • One-off workshop (no series): existing flow — confirm dialog,
  ///     hard-delete just this `scheduled_workshops` row. If attendance
  ///     exists, surface a second strong warning; on confirm, delete
  ///     the attendance rows too.
  ///
  ///   • Recurring workshop (series_id / recurring_series_id set):
  ///     interpret "Șterge definitiv" as "delete the entire series".
  ///     Tear-down order is owned by the repository — see
  ///     `WorkshopsRepository.deleteWorkshopSeries`. The UI's job is to
  ///     measure the impact (number of sessions / attendance rows /
  ///     enrollment links) and gate the destructive action behind one
  ///     or two confirmation dialogs.
  Future<void> _deletePermanently() async {
    final isAdmin =
        ref.read(currentProfileProvider).valueOrNull?.isAdmin ?? false;
    if (!isAdmin) return; // defense in depth; menu is already gated

    final rows =
        ref.read(workshopDetailsProvider(widget.workshopId)).valueOrNull;
    final row = (rows == null || rows.isEmpty) ? null : rows.first;
    if (row == null) return;

    if (row.isRecurringInstance) {
      await _deleteRecurringSeries(row, isAdmin: isAdmin);
    } else {
      await _deleteOneOff(isAdmin: isAdmin);
    }
  }

  // ── One-off deletion ──────────────────────────────────────────────────────

  Future<void> _deleteOneOff({required bool isAdmin}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ștergi definitiv atelierul?'),
        content: const Text(
          'Această acțiune nu poate fi anulată. Atelierul va fi '
          'eliminat din aplicație doar dacă nu are prezențe sau date '
          'istorice asociate.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Renunță'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Șterge definitiv'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(workshopsRepositoryProvider).deleteWorkshopOneOff(
            isAdmin: isAdmin,
            workshopId: widget.workshopId,
          );
      _afterSuccessfulDelete();
    } on WorkshopDeleteBlockedException catch (e) {
      if (!mounted) return;
      if (e.reason == WorkshopDeleteBlockedReason.hasAttendance) {
        // Offer the strong warning + opt-in path.
        await _confirmAttendanceLossAndDeleteOneOff(isAdmin: isAdmin);
        return;
      }
      _showBlockedMessage(e);
    } catch (e) {
      _showGenericError(e);
    }
  }

  Future<void> _confirmAttendanceLossAndDeleteOneOff({
    required bool isAdmin,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Există prezențe înregistrate'),
        content: const Text(
          'Există prezențe înregistrate pentru acest atelier. Dacă '
          'continui, istoricul de prezență pentru această sesiune va fi '
          'șters definitiv. Această acțiune nu poate fi anulată.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Renunță'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Șterge inclusiv istoricul'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(workshopsRepositoryProvider).deleteWorkshopOneOff(
            isAdmin: isAdmin,
            workshopId: widget.workshopId,
            includeAttendance: true,
          );
      _afterSuccessfulDelete();
    } on WorkshopDeleteBlockedException catch (e) {
      _showBlockedMessage(e);
    } catch (e) {
      _showGenericError(e);
    }
  }

  // ── Recurring series deletion ─────────────────────────────────────────────

  Future<void> _deleteRecurringSeries(
    WorkshopDetailRow row, {
    required bool isAdmin,
  }) async {
    final seriesId = row.seriesId ?? row.recurringSeriesId;
    if (seriesId == null || seriesId.isEmpty) return;

    final repo = ref.read(workshopsRepositoryProvider);

    // 1. Measure impact so the dialog can quote concrete numbers.
    SeriesDeletionImpact impact;
    try {
      impact =
          await repo.measureSeriesDeletionImpact(seriesId: seriesId);
    } catch (e) {
      _showGenericError(e);
      return;
    }
    if (!mounted) return;

    // 2. Strong confirmation dialog (recurring series).
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ștergi definitiv atelierul recurent?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Acest atelier face parte dintr-o serie recurentă. Vor '
              'fi șterse toate sesiunile viitoare ale acestei serii și '
              'atelierul nu va mai fi generat automat. Această acțiune '
              'nu poate fi anulată.',
            ),
            const SizedBox(height: 12),
            _ImpactSummary(impact: impact),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Renunță'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Șterge definitiv seria'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // 3. Optional second warning when attendance history would be lost.
    var includeAttendance = false;
    if (impact.attendanceCount > 0) {
      final attendanceConfirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Există prezențe înregistrate'),
          content: Text(
            'Există ${impact.attendanceCount} înregistrări de prezență '
            'pentru această serie. Dacă continui, istoricul de prezență '
            'pentru aceste sesiuni va fi șters definitiv.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Renunță'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continuă și șterge istoricul'),
            ),
          ],
        ),
      );
      if (attendanceConfirmed != true || !mounted) return;
      includeAttendance = true;
    }

    // 4. Execute.
    try {
      await repo.deleteWorkshopSeries(
        isAdmin: isAdmin,
        seriesId: seriesId,
        includeAttendance: includeAttendance,
      );
      _afterSuccessfulDelete();
    } on WorkshopDeleteBlockedException catch (e) {
      _showBlockedMessage(e);
    } catch (e) {
      _showGenericError(e);
    }
  }

  // ── Common cleanup ────────────────────────────────────────────────────────

  void _afterSuccessfulDelete() {
    if (kDebugMode) debugPrint('[Workshop] permanently deleted');
    // Realtime (rt:scheduled_workshops) fires DELETE on the same row
    // and invalidates workshopDetailsProvider(id), workshopByIdProvider(id),
    // allScheduledWorkshopsProvider, todayWorkshopsProvider,
    // workshopsListProvider, dashboardStatsProvider — every list that
    // surfaces this workshop. The page navigates away in the next
    // statement, so a brief realtime delay is invisible to the user.
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Atelierul a fost șters definitiv.')),
    );
    context.canPop() ? context.pop() : context.go('/dashboard');
  }

  void _showBlockedMessage(WorkshopDeleteBlockedException e) {
    if (!mounted) return;
    final message = switch (e.reason) {
      WorkshopDeleteBlockedReason.hasAttendance =>
        'Există prezențe înregistrate pentru această sesiune. Confirmă '
            'din nou pentru a șterge inclusiv istoricul.',
      WorkshopDeleteBlockedReason.recurringSeries =>
        'Acest atelier face parte dintr-o serie recurentă. Folosește '
            'opțiunea de ștergere a seriei.',
      WorkshopDeleteBlockedReason.refusedByServer =>
        'Ștergerea nu a fost executată pe server (probabil permisiuni '
            'insuficiente sau o regulă RLS). Atelierul nu a fost eliminat.',
    };
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _showGenericError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Eroare: $e')));
  }

  Future<void> _cancelSession() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Anulează sesiunea'),
        content: const Text(
          'Sesiunea va fi dezactivată. Datele de prezență existente sunt păstrate.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Nu'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Anulează sesiunea'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref
          .read(workshopsRepositoryProvider)
          .cancelSession(widget.workshopId);
      if (kDebugMode) debugPrint('[Workshop] session cancelled');
      // Await the details refresh so the page reflects the new state
      // before any navigation away from here. The remaining lists
      // (workshopByIdProvider, allScheduledWorkshopsProvider,
      // todayWorkshopsProvider, workshopsListProvider,
      // dashboardStatsProvider) are kept in sync by realtime
      // (rt:scheduled_workshops) — duplicating their invalidates here
      // doubled the refetch cost without changing the user-visible
      // outcome on this page.
      ref.invalidate(workshopDetailsProvider(widget.workshopId));
      await ref.read(workshopDetailsProvider(widget.workshopId).future);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sesiunea a fost anulată.')),
        );
        context.canPop() ? context.pop() : context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Eroare: $e')));
      }
    }
  }

  Future<void> _mark(String childId, String status, String? observation) async {
    if (_marking.contains(childId)) return;
    setState(() => _marking.add(childId));
    try {
      final user = ref.read(currentUserProvider);
      final isStaff =
          ref.read(currentProfileProvider).valueOrNull?.isStaff ?? false;
      await ref.read(workshopsRepositoryProvider).markAttendance(
            isStaff: isStaff,
            workshopId: widget.workshopId,
            childId: childId,
            status: status,
            observation: observation,
            markedBy: user?.id ?? '',
          );
      // Await the details refresh so the row's button color reflects the new
      // attendance status before the spinner clears. Otherwise the button
      // briefly shows the previous status until the cached provider catches up.
      ref.invalidate(workshopDetailsProvider(widget.workshopId));
      await ref.read(workshopDetailsProvider(widget.workshopId).future);
      // allChildrenProvider is intentionally invalidated here because the
      // realtime rt:attendance handler SKIPS it when childId is present
      // (it uses targeted childByIdProvider instead). This is the only
      // refresh path for the children list's last-attendance pill.
      // weeklyAttendancesProvider and dashboardStatsProvider are covered
      // unconditionally by rt:attendance — no manual invalidate needed.
      ref.invalidate(allChildrenProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _marking.remove(childId));
    }
  }

  Future<void> _markAll(List<String> childIds) async {
    if (_markingAll || childIds.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Marchează toți prezenți'),
        content: const Text('Marchezi toți copiii ca prezenți?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Anulează'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmă'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _markingAll = true);
    try {
      final user = ref.read(currentUserProvider);
      final isStaff =
          ref.read(currentProfileProvider).valueOrNull?.isStaff ?? false;
      await ref.read(workshopsRepositoryProvider).markAllPresent(
            isStaff: isStaff,
            workshopId: widget.workshopId,
            childIds: childIds,
            markedBy: user?.id ?? '',
          );
      // Await the details refresh so all rows show their new attendance
      // status before the "marking all" spinner clears.
      // allChildrenProvider stays — realtime rt:attendance skips it when
      // childId is in the payload. weeklyAttendancesProvider /
      // dashboardStatsProvider are covered by realtime unconditionally.
      ref.invalidate(workshopDetailsProvider(widget.workshopId));
      await ref.read(workshopDetailsProvider(widget.workshopId).future);
      if (kDebugMode) debugPrint('[Workshop] all present marked');
      ref.invalidate(allChildrenProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Toți copiii au fost marcați prezenți.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Eroare: $e')));
      }
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailsAsync =
        ref.watch(workshopDetailsProvider(widget.workshopId));
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final isAdmin = profile?.isAdmin ?? false;
    final theme = Theme.of(context);

    // Remember which series this workshop belongs to so we know which
    // enrolled-children provider to listen on.
    final detailsRows = detailsAsync.valueOrNull;
    if (detailsRows != null && detailsRows.isNotEmpty) {
      _listenedSeriesId = detailsRows.first.seriesId;
    }

    // "Șterge definitiv" is enabled for admins as soon as the details
    // have loaded — the recurring branch deletes the entire series,
    // the one-off branch deletes the single row, and `_deletePermanently`
    // picks the right path based on `WorkshopDetailRow.isRecurringInstance`.
    // While loading we keep it disabled so we don't dispatch on stale data.
    final canHardDelete =
        isAdmin && detailsRows != null && detailsRows.isNotEmpty;

    // Central appRealtimeProvider invalidates seriesEnrolledChildrenProvider
    // for the affected series, but it cannot know which scheduled_workshop_id
    // belongs to this view — workshop_enrollments rows only carry series_id.
    // Bridge that gap: whenever the enrolled-children list refreshes for our
    // series, also invalidate this workshop's details provider so the join
    // re-runs and shows the new roster.
    if (_listenedSeriesId != null) {
      ref.listen<AsyncValue<List<SeriesEnrolledChild>>>(
        seriesEnrolledChildrenProvider(_listenedSeriesId!),
        (_, _) {
          if (mounted) {
            ref.invalidate(workshopDetailsProvider(widget.workshopId));
          }
        },
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/dashboard'),
        ),
        title: const Text('Detalii atelier'),
        actions: [
          if (isAdmin)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  context.go('/workshops/${widget.workshopId}/edit');
                } else if (value == 'cancel') {
                  _cancelSession();
                } else if (value == 'delete') {
                  _deletePermanently();
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Editează'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                const PopupMenuItem(
                  value: 'cancel',
                  child: ListTile(
                    leading: Icon(Icons.cancel_outlined,
                        color: AppColors.error),
                    title: Text('Anulează sesiunea',
                        style: TextStyle(color: AppColors.error)),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
                // "Șterge definitiv" is only available for one-off
                // workshops. Recurring instances must be cancelled
                // (the generator skips already-existing rows even when
                // they are inactive, so the cancel sticks).
                if (canHardDelete) const PopupMenuDivider(),
                if (canHardDelete)
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_forever_outlined,
                          color: AppColors.error),
                      title: Text('Șterge definitiv',
                          style: TextStyle(color: AppColors.error)),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: detailsAsync.when(
        skipLoadingOnReload: true,
        loading: () => const AppLoading(),
        error: (e, _) => Center(child: AppError(message: e.toString())),
        data: (rows) {
          if (rows.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_outlined,
                      size: 48, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    'Nu există date pentru acest atelier.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.outline),
                  ),
                ],
              ),
            );
          }

          final first = rows.first;

          // Date restriction: can only mark on or after the workshop date
          final today = DateTime.now();
          final todayDate =
              DateTime(today.year, today.month, today.day);
          final workshopDay = DateTime(
            first.workshopDate.year,
            first.workshopDate.month,
            first.workshopDate.day,
          );
          final canMarkByDate = !todayDate.isBefore(workshopDay);

          // Role-based permission
          final hasRole = isAdmin ||
              (profile?.isTrainer == true &&
                  profile!.id == first.trainerId);
          final canMark = canMarkByDate && hasRole;
          final enrolled =
              rows.where((r) => r.childId != null).toList();

          return SingleChildScrollView(
            padding: context.mobilePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WorkshopHeaderCard(row: first),
                // Banner when workshop is in the future
                if (hasRole && !canMarkByDate) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              AppColors.warning.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_clock_outlined,
                            size: 16, color: AppColors.warning),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Prezența poate fi marcată începând cu ziua atelierului (${formatDate(first.workshopDate)}).',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.warning,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                WorkshopChildrenList(
                  workshopId: widget.workshopId,
                  enrolled: enrolled,
                  marking: _marking,
                  canMark: canMark,
                  onMark: _mark,
                  onChildTap: (childId) =>
                      context.push('/children/$childId'),
                  isAdmin: isAdmin,
                  seriesId: first.seriesId,
                  onEnrolled: () {
                    // Keep this invalidate: realtime reaches
                    // workshopDetailsProvider only via the
                    // `seriesEnrolledChildrenProvider` → ref.listen
                    // bridge defined above, which adds 50–200 ms of
                    // latency. The user just clicked "add" — refresh
                    // the roster immediately. allChildrenProvider is
                    // already covered by rt:workshop_enrollments.
                    ref.invalidate(
                        workshopDetailsProvider(widget.workshopId));
                    if (kDebugMode) {
                      debugPrint(
                          '[Workshop] enrollment done, details refreshed');
                    }
                  },
                  markingAll: _markingAll,
                  onMarkAll: canMark && enrolled.isNotEmpty
                      ? () => _markAll(
                            enrolled
                                .map((r) => r.childId!)
                                .toList(),
                          )
                      : null,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Compact summary of what a series-delete will touch. Rendered inside
/// the strong confirmation dialog so the admin sees the concrete cost
/// before agreeing.
class _ImpactSummary extends StatelessWidget {
  const _ImpactSummary({required this.impact});
  final SeriesDeletionImpact impact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline;
    final children = <Widget>[
      _row(theme, 'Sesiuni programate', impact.scheduledCount, outline),
      _row(theme, 'Înscrieri active', impact.enrollmentCount, outline),
      _row(theme, 'Prezențe înregistrate', impact.attendanceCount,
          impact.attendanceCount > 0 ? AppColors.error : outline),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _row(ThemeData theme, String label, int count, Color trailingColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          Text(
            '$count',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: trailingColor,
            ),
          ),
        ],
      ),
    );
  }
}

