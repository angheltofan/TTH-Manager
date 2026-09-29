import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../auth/providers/auth_providers.dart';
import '../../children/domain/child_row.dart';
import '../../children/providers/children_providers.dart';
// Reuse the workshop info-chip primitive for the compact header info
// row (date · hours · schedule). Public component; no refactor needed.
import '../../workshops/presentation/widgets/workshop_header_card.dart'
    show WorkshopInfoChip;
import '../domain/afterschool_attendance.dart';
import '../domain/afterschool_program.dart';
import '../providers/afterschool_providers.dart';
import 'widgets/afterschool_attendance_row.dart';
import 'widgets/close_afterschool_session_dialog.dart';
import 'widgets/weekday_multi_selector.dart';

/// Per-(program, date) attendance page. UI aligned to the workshop
/// "Detalii atelier" pattern: compact header card with info chips, a
/// section card for "Copii așteptați" holding the attendance list with
/// its own header (icon · title · count pill · actions incl. "Toți
/// prezenți" and "Închide ziua"), and a separate secondary section
/// for "Prezențe în afara programului zilei" when applicable.
///
/// Logic unchanged from Phase 3 (session lazy-generation, expected
/// filtering, attendance transitions, closed-session behaviour,
/// realtime, RLS). The only new backend interaction is the "Marchează
/// toți prezenți" action which calls the pre-existing repository
/// method [AfterschoolAttendanceRepository.markAllPresent] with the
/// EXPECTED child ids only.
class AfterschoolSessionDayPage extends ConsumerWidget {
  const AfterschoolSessionDayPage({
    super.key,
    required this.programId,
    required this.dateIso,
  });
  final String programId;
  final String dateIso;

  DateTime get _date {
    final parts = dateIso.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final isStaff = profile?.isStaff ?? false;

    final programAsync =
        ref.watch(afterschoolProgramByIdProvider(programId));
    final key = AfterschoolDayKey(programId: programId, date: _date);
    final summaryAsync = ref.watch(afterschoolDaySummaryProvider(key));
    final childrenAsync = ref.watch(allChildrenProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prezență Afterschool'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/afterschool/today'),
        ),
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
          return summaryAsync.when(
            loading: () => const SizedBox.expand(child: AppLoading()),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: AppError(message: e.toString()),
            ),
            data: (summary) {
              return childrenAsync.when(
                loading: () =>
                    const SizedBox.expand(child: AppLoading()),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: AppError(message: e.toString()),
                ),
                data: (children) {
                  final byId = {for (final c in children) c.id: c};
                  return _Body(
                    program: program,
                    date: _date,
                    summary: summary,
                    childrenById: byId,
                    isStaff: isStaff,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({
    required this.program,
    required this.date,
    required this.summary,
    required this.childrenById,
    required this.isStaff,
  });

  final AfterschoolProgram program;
  final DateTime date;
  final AfterschoolDaySummary summary;
  final Map<String, ChildRow> childrenById;
  final bool isStaff;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  bool _markingAll = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = widget.summary;

    // Sort expected + unexpected by child name for a stable UI.
    final expected = [...s.expected]..sort((a, b) {
        final na = widget.childrenById[a.childId]?.fullName ?? a.childId;
        final nb = widget.childrenById[b.childId]?.fullName ?? b.childId;
        return na.compareTo(nb);
      });
    final unexpected = [...s.unexpectedAttendance]..sort((a, b) {
        final na = widget.childrenById[a.childId]?.fullName ?? a.childId;
        final nb = widget.childrenById[b.childId]?.fullName ?? b.childId;
        return na.compareTo(nb);
      });

    AfterschoolAttendance? attFor(String childId) {
      for (final a in s.attendance) {
        if (a.childId == childId) return a;
      }
      return null;
    }

    final padding = context.mobilePadding;
    final gap = context.sectionGap;

    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeaderCard(
              program: widget.program,
              date: widget.date,
              summary: s,
              isStaff: widget.isStaff),
          SizedBox(height: gap),
          if (s.isClosed)
            _ClosedBanner(
              reason: s.session?.closedReason,
              isStaff: widget.isStaff,
              sessionId: s.session!.id,
            ),
          if (s.isClosed) SizedBox(height: gap),
          if (!s.sessionExists)
            _NoSessionCard(date: widget.date)
          else
            _SectionCard(
              icon: Icons.groups_2_outlined,
              title: 'Copii așteptați',
              count: expected.length,
              actions: [
                if (widget.isStaff && !s.isClosed && expected.isNotEmpty)
                  _MarkAllPresentButton(
                    loading: _markingAll,
                    onTap: () => _markAllPresent(context, expected),
                  ),
              ],
              child: expected.isEmpty
                  ? _EmptySectionText(
                      'Niciun copil așteptat pentru această zi.',
                      theme: theme,
                    )
                  : Column(
                      children: [
                        for (int i = 0; i < expected.length; i++) ...[
                          if (i > 0)
                            Divider(
                                height: 1,
                                indent: 16,
                                endIndent: 16,
                                color: theme.colorScheme.outline
                                    .withValues(alpha: 0.12)),
                          AfterschoolAttendanceRow(
                            childName: widget.childrenById[expected[i].childId]
                                    ?.fullName ??
                                expected[i].childId,
                            expectedArrivalTime:
                                expected[i].expectedArrivalTime,
                            attendance: attFor(expected[i].childId),
                            locked: s.isClosed || !widget.isStaff,
                            onMark: (status) => _mark(
                              context,
                              sessionId: s.session!.id,
                              childId: expected[i].childId,
                              status: status,
                            ),
                            onUnmark: () => _unmark(
                              context,
                              sessionId: s.session!.id,
                              attendance: attFor(expected[i].childId),
                            ),
                          ),
                        ],
                        Divider(
                            height: 1,
                            color: theme.colorScheme.outline
                                .withValues(alpha: 0.2)),
                        _SummaryStrip(summary: s),
                      ],
                    ),
            ),
          if (unexpected.isNotEmpty) ...[
            SizedBox(height: gap),
            _SectionCard(
              icon: Icons.warning_amber_rounded,
              title: 'Prezențe în afara programului zilei',
              count: unexpected.length,
              accent: AppColors.warning,
              subtitle:
                  'Copii care au marcare pe această zi, dar nu mai '
                  'figurează în programul lor pentru această zi. '
                  'Sunt afișați aici ca să nu se piardă din audit.',
              child: Column(
                children: [
                  for (int i = 0; i < unexpected.length; i++) ...[
                    if (i > 0)
                      Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: theme.colorScheme.outline
                              .withValues(alpha: 0.12)),
                    AfterschoolAttendanceRow(
                      childName:
                          widget.childrenById[unexpected[i].childId]?.fullName ??
                              unexpected[i].childId,
                      attendance: unexpected[i],
                      unexpected: true,
                      locked: s.isClosed || !widget.isStaff,
                      onMark: (status) => _mark(
                        context,
                        sessionId: s.session!.id,
                        childId: unexpected[i].childId,
                        status: status,
                      ),
                      onUnmark: () => _unmark(
                        context,
                        sessionId: s.session!.id,
                        attendance: unexpected[i],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Action handlers ──────────────────────────────────────────────────

  Future<void> _mark(
    BuildContext context, {
    required String sessionId,
    required String childId,
    required AttendanceStatus status,
  }) async {
    final markedBy = ref.read(currentUserIdProvider);
    if (markedBy.isEmpty) return;
    try {
      await ref
          .read(afterschoolAttendanceRepositoryProvider)
          .upsertAttendance(
            isStaff: true,
            sessionId: sessionId,
            childId: childId,
            status: status,
            markedBy: markedBy,
          );
      ref.invalidate(afterschoolAttendanceForSessionProvider(sessionId));
      ref.invalidate(afterschoolDaySummaryProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Eroare la marcare: ${_pretty(e.toString())}')));
      }
    }
  }

  Future<void> _unmark(
    BuildContext context, {
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

  /// Marks every EXPECTED child as present via the pre-existing
  /// [AfterschoolAttendanceRepository.markAllPresent] method (UPSERT
  /// per row, preserves any existing observation). Skips when the
  /// session is closed. Does NOT touch attendance rows for children
  /// outside the expected list — they live in the secondary section.
  Future<void> _markAllPresent(
    BuildContext context,
    List<dynamic> expected,
  ) async {
    final s = widget.summary;
    if (s.isClosed || !s.sessionExists) return;
    if (expected.isEmpty) return;
    final markedBy = ref.read(currentUserIdProvider);
    if (markedBy.isEmpty) return;

    setState(() => _markingAll = true);
    try {
      await ref
          .read(afterschoolAttendanceRepositoryProvider)
          .markAllPresent(
            isStaff: true,
            sessionId: s.session!.id,
            childIds: [for (final e in expected) e.childId as String],
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
      if (mounted) setState(() => _markingAll = false);
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
// Header card — modelled on WorkshopHeaderCard.
// ═════════════════════════════════════════════════════════════════════

class _HeaderCard extends ConsumerWidget {
  const _HeaderCard({
    required this.program,
    required this.date,
    required this.summary,
    required this.isStaff,
  });

  final AfterschoolProgram program;
  final DateTime date;
  final AfterschoolDaySummary summary;
  final bool isStaff;

  static const _monthsRo = [
    'ianuarie', 'februarie', 'martie', 'aprilie', 'mai', 'iunie',
    'iulie', 'august', 'septembrie', 'octombrie', 'noiembrie', 'decembrie',
  ];
  static const _weekdaysRo = [
    'Luni', 'Marți', 'Miercuri', 'Joi', 'Vineri', 'Sâmbătă', 'Duminică',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              if (isStaff && summary.sessionExists && !summary.isClosed)
                _CloseDayButton(sessionId: summary.session!.id),
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
// Section card — modelled on WorkshopChildrenList.
// ═════════════════════════════════════════════════════════════════════

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.count,
    required this.child,
    this.actions = const [],
    this.subtitle,
    this.accent,
  });

  final IconData icon;
  final String title;
  final int count;
  final Widget child;
  final List<Widget> actions;
  final String? subtitle;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = accent ?? AppColors.purple;
    final headerRow = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: tint),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: tint,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ...actions,
      ],
    );

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
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
            child: headerRow,
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                subtitle!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ),
          Divider(
              height: 1,
              color: theme.colorScheme.outline.withValues(alpha: 0.2)),
          child,
        ],
      ),
    );
  }
}

class _MarkAllPresentButton extends StatelessWidget {
  const _MarkAllPresentButton({required this.onTap, required this.loading});
  final VoidCallback onTap;
  final bool loading;

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
              label: const Text('Toți prezenți'),
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

// ═════════════════════════════════════════════════════════════════════
// Summary strip — matches the workshop _AttendanceSummaryRow style.
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
          _summaryPill('Prezenți', summary.presentCount, AppColors.success),
          _summaryPill('Absenți', summary.absentCount, AppColors.error),
          _summaryPill('Nemarcați', summary.unmarkedCount,
              theme.colorScheme.outline),
        ],
      ),
    );
  }

  Widget _summaryPill(String label, int count, Color color) {
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

// ═════════════════════════════════════════════════════════════════════
// Closed banner + fallback states.
// ═════════════════════════════════════════════════════════════════════

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

class _EmptySectionText extends StatelessWidget {
  const _EmptySectionText(this.text, {required this.theme});
  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(
          text,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
      ),
    );
  }
}
