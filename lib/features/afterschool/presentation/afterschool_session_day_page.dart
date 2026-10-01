import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../../../core/widgets/loading_state.dart';
import '../../auth/providers/auth_providers.dart';
import '../../children/domain/child_row.dart';
import '../../children/providers/children_providers.dart';
// Reuse the workshop info chip + attendance primitives + dialog.
import '../../workshops/presentation/widgets/attendance_dialog.dart'
    show AttendanceDialog;
import '../../workshops/presentation/widgets/attendance_mark_row.dart'
    show AttendanceToggleButton, AttendanceStatusChip;
import '../../workshops/presentation/widgets/workshop_header_card.dart'
    show WorkshopInfoChip;
import '../domain/afterschool_attendance.dart';
import '../domain/afterschool_enrollment.dart';
import '../domain/afterschool_program.dart';
import '../providers/afterschool_providers.dart';
import 'widgets/afterschool_day_navigator.dart';
import 'widgets/close_afterschool_session_dialog.dart';
import 'widgets/edit_enrollment_dialog.dart';
import 'widgets/end_enrollment_dialog.dart';
import 'widgets/enroll_child_dialog.dart';
import 'widgets/weekday_multi_selector.dart';

/// Unified operational page for one Afterschool program.
///
/// Mirrors the workshop "Detalii atelier" layout:
///   • Header card: program name + "Afterschool" badge + info chips
///     (data · ore · zile · tarif lunar) + admin edit menu + close-day
///     action.
///   • Day navigator below the header (Afterschool is per-day; the
///     workshop detail page doesn't need one because sessions already
///     carry their own date).
///   • ONE "Copii înscriși" section — header with count pill + "Adaugă
///     copii" + "Marchează toți prezenți", a list of rows for the
///     children expected that day with Prezent/Absent toggles, and a
///     Prezenți/Absenți/Nemarcați summary strip. Per-row admin popup
///     menu edits or ends the enrollment inline — no second list.
///   • Secondary "Prezențe în afara programului zilei" section when
///     applicable (unexpected marks, same shape as before).
///
/// Backend unchanged. Only the single list; no duplicate "Copii
/// înscriși în program" admin section.
class AfterschoolSessionDayPage extends ConsumerStatefulWidget {
  const AfterschoolSessionDayPage({
    super.key,
    required this.programId,
    required this.dateIso,
  });

  final String programId;
  final String dateIso;

  @override
  ConsumerState<AfterschoolSessionDayPage> createState() =>
      _AfterschoolSessionDayPageState();
}

class _AfterschoolSessionDayPageState
    extends ConsumerState<AfterschoolSessionDayPage> {
  late DateTime _date = _parseIso(widget.dateIso);
  final Set<String> _marking = {};
  bool _markingAll = false;

  static DateTime _parseIso(String iso) {
    final parts = iso.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final isStaff = profile?.isStaff ?? false;
    final isAdmin = profile?.isAdmin ?? false;

    final programAsync =
        ref.watch(afterschoolProgramByIdProvider(widget.programId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalii program'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/afterschool/programs'),
        ),
        actions: [
          if (isAdmin)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') {
                  context.go('/afterschool/programs/${widget.programId}/edit');
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Editează programul'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
              ],
            ),
        ],
      ),
      body: programAsync.when(
        loading: () => const SizedBox.expand(child: AppLoading()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: AppError(message: e.toString()),
        ),
        data: (program) {
          if (program == null) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: AppError(message: 'Program inexistent.'),
            );
          }
          return _Body(
            program: program,
            date: _date,
            isStaff: isStaff,
            isAdmin: isAdmin,
            marking: _marking,
            markingAll: _markingAll,
            onDateChanged: (d) => setState(() => _date = d),
            onMarkStart: (childId) => setState(() => _marking.add(childId)),
            onMarkEnd: (childId) => setState(() => _marking.remove(childId)),
            onMarkingAllChanged: (v) => setState(() => _markingAll = v),
          );
        },
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.program,
    required this.date,
    required this.isStaff,
    required this.isAdmin,
    required this.marking,
    required this.markingAll,
    required this.onDateChanged,
    required this.onMarkStart,
    required this.onMarkEnd,
    required this.onMarkingAllChanged,
  });

  final AfterschoolProgram program;
  final DateTime date;
  final bool isStaff;
  final bool isAdmin;
  final Set<String> marking;
  final bool markingAll;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<String> onMarkStart;
  final ValueChanged<String> onMarkEnd;
  final ValueChanged<bool> onMarkingAllChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final key = AfterschoolDayKey(programId: program.id, date: date);
    final summaryAsync = ref.watch(afterschoolDaySummaryProvider(key));
    final childrenAsync = ref.watch(allChildrenProvider);
    final padding = context.mobilePadding;
    final gap = context.sectionGap;

    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeaderCard(
            program: program,
            date: date,
            summary: summaryAsync.valueOrNull,
            isStaff: isStaff,
          ),
          SizedBox(height: gap),
          AfterschoolDayNavigator(
            date: date,
            onDateChanged: onDateChanged,
          ),
          SizedBox(height: gap),
          summaryAsync.when(
            loading: () =>
                const SizedBox(height: 120, child: AppLoading()),
            error: (e, _) => AppError(message: e.toString()),
            data: (summary) => childrenAsync.when(
              loading: () =>
                  const SizedBox(height: 80, child: AppLoading()),
              error: (e, _) => AppError(message: e.toString()),
              data: (children) {
                final byId = {for (final c in children) c.id: c};
                return _DayContent(
                  program: program,
                  summary: summary,
                  childrenById: byId,
                  isStaff: isStaff,
                  isAdmin: isAdmin,
                  marking: marking,
                  markingAll: markingAll,
                  onMarkStart: onMarkStart,
                  onMarkEnd: onMarkEnd,
                  onMarkingAllChanged: onMarkingAllChanged,
                  theme: theme,
                  gap: gap,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// Day content — closed banner / no-session / enrolments list / unexpected.
// ═════════════════════════════════════════════════════════════════════

class _DayContent extends ConsumerWidget {
  const _DayContent({
    required this.program,
    required this.summary,
    required this.childrenById,
    required this.isStaff,
    required this.isAdmin,
    required this.marking,
    required this.markingAll,
    required this.onMarkStart,
    required this.onMarkEnd,
    required this.onMarkingAllChanged,
    required this.theme,
    required this.gap,
  });

  final AfterschoolProgram program;
  final AfterschoolDaySummary summary;
  final Map<String, ChildRow> childrenById;
  final bool isStaff;
  final bool isAdmin;
  final Set<String> marking;
  final bool markingAll;
  final ValueChanged<String> onMarkStart;
  final ValueChanged<String> onMarkEnd;
  final ValueChanged<bool> onMarkingAllChanged;
  final ThemeData theme;
  final double gap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = summary;
    final expected = [...s.expected]..sort((a, b) {
        final na = childrenById[a.childId]?.fullName ?? a.childId;
        final nb = childrenById[b.childId]?.fullName ?? b.childId;
        return na.compareTo(nb);
      });
    final unexpected = [...s.unexpectedAttendance]..sort((a, b) {
        final na = childrenById[a.childId]?.fullName ?? a.childId;
        final nb = childrenById[b.childId]?.fullName ?? b.childId;
        return na.compareTo(nb);
      });

    AfterschoolAttendance? attFor(String childId) {
      for (final a in s.attendance) {
        if (a.childId == childId) return a;
      }
      return null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (s.isClosed) ...[
          _ClosedBanner(
            reason: s.session?.closedReason,
            isStaff: isStaff,
            sessionId: s.session!.id,
          ),
          SizedBox(height: gap),
        ],
        if (!s.sessionExists)
          _NoSessionCard(date: summary.session?.sessionDate ?? DateTime.now())
        else
          _EnrolmentsListCard(
            program: program,
            expected: expected,
            summary: s,
            childrenById: childrenById,
            attFor: attFor,
            isStaff: isStaff,
            isAdmin: isAdmin,
            marking: marking,
            markingAll: markingAll,
            onMark: (childId, status, observation) => _mark(
              context,
              ref,
              sessionId: s.session!.id,
              childId: childId,
              status: status,
              observation: observation,
            ),
            onUnmark: (att) => _unmark(
              context,
              ref,
              sessionId: s.session!.id,
              attendance: att,
            ),
            onMarkAll: () => _markAllPresent(context, ref, s, expected),
          ),
        if (unexpected.isNotEmpty) ...[
          SizedBox(height: gap),
          _UnexpectedList(
            program: program,
            unexpected: unexpected,
            childrenById: childrenById,
            isStaff: isStaff,
            onMark: (childId, status, observation) => _mark(
              context,
              ref,
              sessionId: s.session!.id,
              childId: childId,
              status: status,
              observation: observation,
            ),
            onUnmark: (att) => _unmark(
              context,
              ref,
              sessionId: s.session!.id,
              attendance: att,
            ),
          ),
        ],
      ],
    );
  }

  // ── Action handlers ──────────────────────────────────────────────────

  Future<void> _mark(
    BuildContext context,
    WidgetRef ref, {
    required String sessionId,
    required String childId,
    required AttendanceStatus status,
    String? observation,
  }) async {
    if (marking.contains(childId)) return;
    final markedBy = ref.read(currentUserIdProvider);
    if (markedBy.isEmpty) return;
    onMarkStart(childId);
    try {
      await ref
          .read(afterschoolAttendanceRepositoryProvider)
          .upsertAttendance(
            isStaff: true,
            sessionId: sessionId,
            childId: childId,
            status: status,
            observation: observation,
            markedBy: markedBy,
          );
      ref.invalidate(afterschoolAttendanceForSessionProvider(sessionId));
      ref.invalidate(afterschoolDaySummaryProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Eroare la marcare: ${_pretty(e.toString())}')));
      }
    } finally {
      onMarkEnd(childId);
    }
  }

  Future<void> _unmark(
    BuildContext context,
    WidgetRef ref, {
    required String sessionId,
    required AfterschoolAttendance? attendance,
  }) async {
    if (attendance == null) return;
    try {
      await ref
          .read(afterschoolAttendanceRepositoryProvider)
          .deleteAttendance(isAdmin: true, attendanceId: attendance.id);
      ref.invalidate(afterschoolAttendanceForSessionProvider(sessionId));
      ref.invalidate(afterschoolDaySummaryProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Eroare la anulare: ${_pretty(e.toString())}')));
      }
    }
  }

  Future<void> _markAllPresent(
    BuildContext context,
    WidgetRef ref,
    AfterschoolDaySummary s,
    List<AfterschoolEnrollment> expected,
  ) async {
    if (s.isClosed || !s.sessionExists) return;
    if (expected.isEmpty) return;
    final markedBy = ref.read(currentUserIdProvider);
    if (markedBy.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Marchează toți prezenți'),
        content: const Text('Marchezi toți copiii ca prezenți?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Anulează')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmă')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    onMarkingAllChanged(true);
    try {
      await ref
          .read(afterschoolAttendanceRepositoryProvider)
          .markAllPresent(
            isStaff: true,
            sessionId: s.session!.id,
            childIds: [for (final e in expected) e.childId],
            markedBy: markedBy,
          );
      ref.invalidate(afterschoolAttendanceForSessionProvider(s.session!.id));
      ref.invalidate(afterschoolDaySummaryProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Toți copiii marcati prezenți.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Eroare: ${_pretty(e.toString())}')));
      }
    } finally {
      onMarkingAllChanged(false);
    }
  }

  String _pretty(String raw) {
    if (raw.contains('row-level security')) {
      return 'Nu ai permisiunea necesară.';
    }
    return raw;
  }
}

// ═════════════════════════════════════════════════════════════════════
// Header card.
// ═════════════════════════════════════════════════════════════════════

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.program,
    required this.date,
    required this.summary,
    required this.isStaff,
  });

  final AfterschoolProgram program;
  final DateTime date;
  final AfterschoolDaySummary? summary;
  final bool isStaff;

  static const _monthsRo = [
    'ianuarie', 'februarie', 'martie', 'aprilie', 'mai', 'iunie',
    'iulie', 'august', 'septembrie', 'octombrie', 'noiembrie', 'decembrie',
  ];
  static const _weekdaysRo = [
    'Luni', 'Marți', 'Miercuri', 'Joi', 'Vineri', 'Sâmbătă', 'Duminică',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = context.isMobile;
    final dayLabel = _weekdaysRo[date.weekday - 1];
    final dateLabel =
        '$dayLabel, ${date.day} ${_monthsRo[date.month - 1]} ${date.year}';
    final hours =
        '${program.startTimeShort} – ${program.endTimeShort}';

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 22),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
        border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: isMobile ? 44 : 52,
                height: isMobile ? 44 : 52,
                decoration: BoxDecoration(
                  color: AppColors.purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(isMobile ? 12 : 14),
                ),
                child: Icon(Icons.school_outlined,
                    color: AppColors.purple, size: isMobile ? 22 : 26),
              ),
              SizedBox(width: isMobile ? 12 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      program.name,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.purple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.purple.withValues(alpha: 0.25)),
                      ),
                      child: const Text(
                        'Afterschool',
                        style: TextStyle(
                            color: AppColors.purple,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              if (isStaff &&
                  (summary?.sessionExists ?? false) &&
                  !(summary?.isClosed ?? false))
                _CloseDayButton(sessionId: summary!.session!.id),
            ],
          ),
          SizedBox(height: isMobile ? 14 : 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              WorkshopInfoChip(
                icon: Icons.calendar_today_outlined,
                label: dateLabel,
                color: AppColors.purple,
              ),
              WorkshopInfoChip(
                icon: Icons.access_time_rounded,
                label: hours,
                color: AppColors.info,
              ),
              WorkshopInfoChip(
                icon: Icons.event_repeat,
                label: formatIsoWeekdaysShort(program.daysOfWeek),
                color: AppColors.success,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CloseDayButton extends ConsumerWidget {
  const _CloseDayButton({required this.sessionId});
  final String sessionId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton.icon(
      icon: const Icon(Icons.lock_outline, size: 15),
      label: const Text('Închide ziua'),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.error,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        textStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      onPressed: () async {
        final ok = await showCloseAfterschoolSessionDialog(
          context: context,
          ref: ref,
          sessionId: sessionId,
        );
        if (ok == true) {
          ref.invalidate(afterschoolSessionForDateProvider);
          ref.invalidate(afterschoolDaySummaryProvider);
        }
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// Single "Copii înscriși" section — mirrors the workshop
// WorkshopChildrenList: responsive header (count + Adaugă + Toți
// prezenți), per-row attendance toggle + admin menu, summary strip.
// ═════════════════════════════════════════════════════════════════════

class _EnrolmentsListCard extends StatelessWidget {
  const _EnrolmentsListCard({
    required this.program,
    required this.expected,
    required this.summary,
    required this.childrenById,
    required this.attFor,
    required this.isStaff,
    required this.isAdmin,
    required this.marking,
    required this.markingAll,
    required this.onMark,
    required this.onUnmark,
    required this.onMarkAll,
  });

  final AfterschoolProgram program;
  final List<AfterschoolEnrollment> expected;
  final AfterschoolDaySummary summary;
  final Map<String, ChildRow> childrenById;
  final AfterschoolAttendance? Function(String childId) attFor;
  final bool isStaff;
  final bool isAdmin;
  final Set<String> marking;
  final bool markingAll;
  final Future<void> Function(
          String childId, AttendanceStatus status, String? observation)
      onMark;
  final Future<void> Function(AfterschoolAttendance att) onUnmark;
  final VoidCallback onMarkAll;

  bool get _canInteract => isStaff && !summary.isClosed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: context.isMobile
                ? _MobileHeader(
                    count: expected.length,
                    isAdmin: isAdmin,
                    program: program,
                    canMarkAll: _canInteract && expected.isNotEmpty,
                    markingAll: markingAll,
                    onMarkAll: onMarkAll,
                    theme: theme,
                  )
                : _DesktopHeader(
                    count: expected.length,
                    isAdmin: isAdmin,
                    program: program,
                    canMarkAll: _canInteract && expected.isNotEmpty,
                    markingAll: markingAll,
                    onMarkAll: onMarkAll,
                    theme: theme,
                  ),
          ),
          Divider(
              height: 1,
              color: theme.colorScheme.outline.withValues(alpha: 0.2)),
          if (expected.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Niciun copil înscris pentru ziua aceasta.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: expected.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: theme.colorScheme.outline.withValues(alpha: 0.12),
              ),
              itemBuilder: (context, i) {
                final e = expected[i];
                final att = attFor(e.childId);
                final name = childrenById[e.childId]?.fullName ?? e.childId;
                return _EnrolmentRow(
                  program: program,
                  enrollment: e,
                  childName: name,
                  attendance: att,
                  isLoading: marking.contains(e.childId),
                  locked: summary.isClosed || !isStaff,
                  isAdmin: isAdmin,
                  onMark: (status, observation) =>
                      onMark(e.childId, status, observation),
                  onUnmark: att == null ? null : () => onUnmark(att),
                );
              },
            ),
          if (expected.isNotEmpty) ...[
            Divider(
                height: 1,
                color: theme.colorScheme.outline.withValues(alpha: 0.2)),
            _SummaryStrip(summary: summary),
          ],
        ],
      ),
    );
  }
}

class _DesktopHeader extends StatelessWidget {
  const _DesktopHeader({
    required this.count,
    required this.isAdmin,
    required this.program,
    required this.canMarkAll,
    required this.markingAll,
    required this.onMarkAll,
    required this.theme,
  });

  final int count;
  final bool isAdmin;
  final AfterschoolProgram program;
  final bool canMarkAll;
  final bool markingAll;
  final VoidCallback onMarkAll;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.purple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.people_outline,
              size: 16, color: AppColors.purple),
        ),
        const SizedBox(width: 10),
        Text(
          'Copii înscriși',
          style: theme.textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.purple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
                color: AppColors.purple,
                fontSize: 12,
                fontWeight: FontWeight.w700),
          ),
        ),
        if (isAdmin) _AddChildrenButton(program: program),
        if (canMarkAll)
          _MarkAllPresentButton(onTap: onMarkAll, loading: markingAll),
      ],
    );
  }
}

class _MobileHeader extends StatelessWidget {
  const _MobileHeader({
    required this.count,
    required this.isAdmin,
    required this.program,
    required this.canMarkAll,
    required this.markingAll,
    required this.onMarkAll,
    required this.theme,
  });

  final int count;
  final bool isAdmin;
  final AfterschoolProgram program;
  final bool canMarkAll;
  final bool markingAll;
  final VoidCallback onMarkAll;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final hasActions = isAdmin || canMarkAll;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.people_outline,
                  size: 16, color: AppColors.purple),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Copii înscriși',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                    color: AppColors.purple,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        if (hasActions) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              if (isAdmin) _AddChildrenButton(program: program),
              if (canMarkAll)
                _MarkAllPresentButton(
                  onTap: onMarkAll,
                  loading: markingAll,
                  shortLabel: true,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _MarkAllPresentButton extends StatelessWidget {
  const _MarkAllPresentButton({
    required this.onTap,
    required this.loading,
    this.shortLabel = false,
  });
  final VoidCallback onTap;
  final bool loading;
  final bool shortLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : TextButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.done_all_rounded, size: 15),
              label: Text(
                  shortLabel ? 'Toți prezenți' : 'Marchează toți prezenți'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.success,
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                textStyle: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
    );
  }
}

class _AddChildrenButton extends ConsumerWidget {
  const _AddChildrenButton({required this.program});
  final AfterschoolProgram program;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync =
        ref.watch(afterschoolActiveEnrollmentCountProvider(program.id));
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: TextButton.icon(
        onPressed: () async {
          final count = countAsync.valueOrNull ?? 0;
          await showEnrollChildDialog(
            context: context,
            ref: ref,
            program: program,
            currentActiveCount: count,
          );
        },
        icon: const Icon(Icons.person_add_alt_1_outlined, size: 15),
        label: const Text('Adaugă copii'),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.purple,
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          textStyle: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ── One row inside the "Copii înscriși" list ─────────────────────────

class _EnrolmentRow extends ConsumerWidget {
  const _EnrolmentRow({
    required this.program,
    required this.enrollment,
    required this.childName,
    required this.attendance,
    required this.isLoading,
    required this.locked,
    required this.isAdmin,
    required this.onMark,
    required this.onUnmark,
  });

  final AfterschoolProgram program;
  final AfterschoolEnrollment enrollment;
  final String childName;
  final AfterschoolAttendance? attendance;
  final bool isLoading;
  final bool locked;
  final bool isAdmin;
  final void Function(AttendanceStatus status, String? observation) onMark;
  final VoidCallback? onUnmark;

  String? get _arrivalShort {
    final t = enrollment.expectedArrivalTime;
    if (t == null || t.isEmpty) return null;
    return t.length >= 5 ? t.substring(0, 5) : t;
  }

  void _openDialog(BuildContext context, String initialStatus) {
    showDialog<void>(
      context: context,
      builder: (_) => AttendanceDialog(
        initialStatus: initialStatus,
        currentObs: attendance?.observation,
        onSave: (status, observation) {
          final mapped = status == 'present'
              ? AttendanceStatus.present
              : AttendanceStatus.absent;
          onMark(mapped, observation);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final statusDb = attendance?.status.toDb();
    final obs = attendance?.observation;

    final nameBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          childName,
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (_arrivalShort != null)
          Text(
            'Sosire estimată: ${_arrivalShort!}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        if (obs != null && obs.isNotEmpty)
          Text(
            obs,
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
                fontStyle: FontStyle.italic),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );

    final controls = isLoading
        ? const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : locked
            ? AttendanceStatusChip(status: statusDb)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AttendanceToggleButton(
                    label: 'Prezent',
                    icon: Icons.check_rounded,
                    selected: statusDb == 'present',
                    selectedColor: AppColors.success,
                    onTap: () => _openDialog(context, 'present'),
                  ),
                  const SizedBox(width: 8),
                  AttendanceToggleButton(
                    label: 'Absent',
                    icon: Icons.close_rounded,
                    selected: statusDb == 'absent',
                    selectedColor: AppColors.error,
                    onTap: () => _openDialog(context, 'absent'),
                  ),
                  if (onUnmark != null) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Anulează marcarea',
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: onUnmark,
                    ),
                  ],
                ],
              );

    final adminMenu = isAdmin
        ? PopupMenuButton<String>(
            tooltip: 'Acțiuni admin',
            icon: Icon(Icons.more_horiz, color: theme.colorScheme.outline),
            onSelected: (v) async {
              switch (v) {
                case 'edit':
                  await showEditEnrollmentDialog(
                    context: context,
                    ref: ref,
                    program: program,
                    enrollment: enrollment,
                    childName: childName,
                  );
                  break;
                case 'end':
                  await showEndEnrollmentDialog(
                    context: context,
                    ref: ref,
                    program: program,
                    enrollment: enrollment,
                    childName: childName,
                  );
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Editează înscrierea'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              PopupMenuItem(
                value: 'end',
                child: ListTile(
                  leading: Icon(Icons.event_busy_outlined),
                  title: Text('Încheie înscrierea'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
            ],
          )
        : const SizedBox.shrink();

    // Tap target scoped to the avatar + name block so Prezent/Absent,
    // the un-mark × and the admin menu stay independent (same pattern
    // as the workshop row — see workshop_details_page.dart L461).
    void goToChild() => context.push('/children/${enrollment.childId}');

    if (context.isMobile) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: goToChild,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          ChildAvatar(name: childName, size: 36),
                          const SizedBox(width: 10),
                          Expanded(child: nameBlock),
                        ],
                      ),
                    ),
                  ),
                ),
                if (isAdmin) adminMenu,
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 46),
              child: controls,
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: goToChild,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    ChildAvatar(name: childName, size: 40),
                    const SizedBox(width: 12),
                    Expanded(child: nameBlock),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          controls,
          if (isAdmin) adminMenu,
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// Unexpected marks — secondary list for audit.
// ═════════════════════════════════════════════════════════════════════

class _UnexpectedList extends StatelessWidget {
  const _UnexpectedList({
    required this.program,
    required this.unexpected,
    required this.childrenById,
    required this.isStaff,
    required this.onMark,
    required this.onUnmark,
  });

  final AfterschoolProgram program;
  final List<AfterschoolAttendance> unexpected;
  final Map<String, ChildRow> childrenById;
  final bool isStaff;
  final Future<void> Function(
          String childId, AttendanceStatus status, String? observation)
      onMark;
  final Future<void> Function(AfterschoolAttendance att) onUnmark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.warning_amber_rounded,
                      size: 16, color: AppColors.warning),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Prezențe în afara programului zilei',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${unexpected.length}',
                    style: const TextStyle(
                      color: AppColors.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
              height: 1,
              color: theme.colorScheme.outline.withValues(alpha: 0.2)),
          for (int i = 0; i < unexpected.length; i++) ...[
            if (i > 0)
              Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: theme.colorScheme.outline.withValues(alpha: 0.12)),
            _UnexpectedRow(
              program: program,
              attendance: unexpected[i],
              childName:
                  childrenById[unexpected[i].childId]?.fullName ??
                      unexpected[i].childId,
              locked: !isStaff,
              onMark: (status, observation) =>
                  onMark(unexpected[i].childId, status, observation),
              onUnmark: () => onUnmark(unexpected[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _UnexpectedRow extends StatelessWidget {
  const _UnexpectedRow({
    required this.program,
    required this.attendance,
    required this.childName,
    required this.locked,
    required this.onMark,
    required this.onUnmark,
  });
  final AfterschoolProgram program;
  final AfterschoolAttendance attendance;
  final String childName;
  final bool locked;
  final void Function(AttendanceStatus status, String? observation) onMark;
  final VoidCallback onUnmark;

  void _openDialog(BuildContext context, String initialStatus) {
    showDialog<void>(
      context: context,
      builder: (_) => AttendanceDialog(
        initialStatus: initialStatus,
        currentObs: attendance.observation,
        onSave: (status, observation) {
          final mapped = status == 'present'
              ? AttendanceStatus.present
              : AttendanceStatus.absent;
          onMark(mapped, observation);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusDb = attendance.status.toDb();
    final controls = locked
        ? AttendanceStatusChip(status: statusDb)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AttendanceToggleButton(
                label: 'Prezent',
                icon: Icons.check_rounded,
                selected: statusDb == 'present',
                selectedColor: AppColors.success,
                onTap: () => _openDialog(context, 'present'),
              ),
              const SizedBox(width: 8),
              AttendanceToggleButton(
                label: 'Absent',
                icon: Icons.close_rounded,
                selected: statusDb == 'absent',
                selectedColor: AppColors.error,
                onTap: () => _openDialog(context, 'absent'),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Anulează marcarea',
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close, size: 16),
                onPressed: onUnmark,
              ),
            ],
          );

    final nameBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          childName,
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.25)),
            ),
            child: const Text(
              'În afara programului',
              style: TextStyle(
                color: AppColors.warning,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        if (attendance.observation != null &&
            attendance.observation!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              attendance.observation!,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontStyle: FontStyle.italic),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );

    void goToChild() => context.push('/children/${attendance.childId}');

    if (context.isMobile) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: goToChild,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    ChildAvatar(name: childName, size: 36),
                    const SizedBox(width: 10),
                    Expanded(child: nameBlock),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 46),
              child: controls,
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: goToChild,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    ChildAvatar(name: childName, size: 40),
                    const SizedBox(width: 12),
                    Expanded(child: nameBlock),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          controls,
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// Summary strip + fallback states.
// ═════════════════════════════════════════════════════════════════════

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.summary});
  final AfterschoolDaySummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          _pill('Prezenți', summary.presentCount, AppColors.success),
          _pill('Absenți', summary.absentCount, AppColors.error),
          _pill('Nemarcați', summary.unmarkedCount,
              theme.colorScheme.outline),
        ],
      ),
    );
  }

  Widget _pill(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count $label',
        style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ClosedBanner extends ConsumerWidget {
  const _ClosedBanner({
    required this.reason,
    required this.isStaff,
    required this.sessionId,
  });
  final String? reason;
  final bool isStaff;
  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.muted.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.muted.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.lock_outline, color: AppColors.muted, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Zi închisă',
                  style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted)),
              if (reason != null && reason!.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(reason!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline)),
              ],
            ],
          ),
        ),
        if (isStaff)
          TextButton.icon(
            icon: const Icon(Icons.lock_open, size: 15),
            label: const Text('Redeschide'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.info,
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              textStyle: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600),
            ),
            onPressed: () async {
              try {
                await ref
                    .read(afterschoolSessionsRepositoryProvider)
                    .reopenSession(sessionId: sessionId);
                ref.invalidate(afterschoolSessionForDateProvider);
                ref.invalidate(afterschoolDaySummaryProvider);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Nu s-a putut redeschide: $e')));
                }
              }
            },
          ),
      ]),
    );
  }
}

class _NoSessionCard extends StatelessWidget {
  const _NoSessionCard({required this.date});
  final DateTime date;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.35)),
      ),
      child: Column(children: [
        Icon(Icons.event_busy_outlined,
            size: 36, color: theme.colorScheme.outline),
        const SizedBox(height: 8),
        Text('Nu a existat sesiune programată',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          'În această zi programul nu era activ sau ziua nu se '
          'încadra în orarul lui.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
      ]),
    );
  }
}
