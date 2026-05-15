import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../auth/providers/auth_providers.dart';
import '../../children/providers/children_providers.dart';
import '../../dashboard/providers/dashboard_providers.dart';
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
  RealtimeChannel? _attChannel;
  RealtimeChannel? _enrollmentChannel;
  String? _subscribedSeriesId;

  @override
  void initState() {
    super.initState();
    _subscribeToAttendance();
  }

  void _subscribeToAttendance() {
    _attChannel = Supabase.instance.client
        .channel('att:ws:${widget.workshopId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'attendance',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'scheduled_workshop_id',
            value: widget.workshopId,
          ),
          callback: (payload) {
            if (kDebugMode) {
              debugPrint(
                '[RT] att:ws:${widget.workshopId} → ${payload.eventType}',
              );
            }
            if (mounted) {
              if (kDebugMode) debugPrint('[RT] invalidating workshopDetailsProvider(${widget.workshopId})');
              ref.invalidate(workshopDetailsProvider(widget.workshopId));
              ref.invalidate(allChildrenProvider);
              ref.invalidate(weeklyAttendancesProvider);
              ref.invalidate(dashboardStatsProvider);
            }
          },
        )
        .subscribe((status, [error]) {
          if (kDebugMode) {
            debugPrint(
              '[RT] subscribed att:ws:${widget.workshopId} → $status',
            );
          }
        });
  }

  @override
  void dispose() {
    if (_attChannel != null) {
      Supabase.instance.client.removeChannel(_attChannel!);
    }
    if (_enrollmentChannel != null) {
      Supabase.instance.client.removeChannel(_enrollmentChannel!);
    }
    super.dispose();
  }

  /// Subscribes to [workshop_enrollments] for the series that this workshop
  /// belongs to. Called once we have the [seriesId] from the loaded data.
  void _subscribeToEnrollmentsIfNeeded(String? seriesId) {
    if (seriesId == null || seriesId == _subscribedSeriesId) return;
    _subscribedSeriesId = seriesId;
    if (kDebugMode) {
      debugPrint('[RT] enroll:ws:$seriesId: subscribing');
    }
    _enrollmentChannel = Supabase.instance.client
        .channel('enroll:ws:$seriesId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'workshop_enrollments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'series_id',
            value: seriesId,
          ),
          callback: (payload) {
            if (kDebugMode) {
              debugPrint(
                '[RT] enroll:ws:$seriesId → ${payload.eventType}',
              );
            }
            if (mounted) {
              ref.invalidate(workshopDetailsProvider(widget.workshopId));
              ref.invalidate(seriesEnrolledChildrenProvider(seriesId));
              ref.invalidate(availableChildrenForSeriesProvider(seriesId));
              ref.invalidate(activeWorkshopSeriesProvider);
            }
          },
        )
        .subscribe((status, [error]) {
          if (kDebugMode) {
            debugPrint('[RT] enroll:ws:$seriesId → $status');
          }
        });
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
      ref.invalidate(workshopDetailsProvider(widget.workshopId));
      ref.invalidate(workshopByIdProvider(widget.workshopId));
      ref.invalidate(allScheduledWorkshopsProvider);
      ref.invalidate(todayWorkshopsProvider);
      ref.invalidate(workshopsListProvider);
      ref.invalidate(dashboardStatsProvider);
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
      await ref.read(workshopsRepositoryProvider).markAttendance(
            workshopId: widget.workshopId,
            childId: childId,
            status: status,
            observation: observation,
            markedBy: user?.id ?? '',
          );
      ref.invalidate(workshopDetailsProvider(widget.workshopId));
      ref.invalidate(allChildrenProvider);
      ref.invalidate(weeklyAttendancesProvider);
      ref.invalidate(dashboardStatsProvider);
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
      await ref.read(workshopsRepositoryProvider).markAllPresent(
            workshopId: widget.workshopId,
            childIds: childIds,
            markedBy: user?.id ?? '',
          );
      ref.invalidate(workshopDetailsProvider(widget.workshopId));
      if (kDebugMode) debugPrint('[Workshop] all present marked');
      ref.invalidate(allChildrenProvider);
      ref.invalidate(weeklyAttendancesProvider);
      ref.invalidate(dashboardStatsProvider);
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

    // Subscribe to enrollment realtime once we know the series id.
    ref.listen<AsyncValue<List<WorkshopDetailRow>>>(
      workshopDetailsProvider(widget.workshopId),
      (_, next) {
        final rows = next.valueOrNull;
        final seriesId = (rows != null && rows.isNotEmpty)
            ? rows.first.seriesId
            : null;
        _subscribeToEnrollmentsIfNeeded(seriesId);
      },
    );

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
                    ref.invalidate(
                        workshopDetailsProvider(widget.workshopId));
                    ref.invalidate(allChildrenProvider);
                    if (kDebugMode) {
                      debugPrint('[Workshop] enrollment done, providers invalidated');
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

