import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../domain/afterschool_program.dart';
import '../../providers/afterschool_providers.dart';
import 'weekday_multi_selector.dart';

/// One program tile on the "Astăzi" page. Shows name, hours, and the
/// four counts (expected / present / absent / unmarked). If the
/// session is closed the counts are replaced by a "Zi închisă" pill
/// and the closure reason. Tapping the card navigates to the
/// per-session day page for [date].
class AfterschoolProgramTodayCard extends ConsumerWidget {
  const AfterschoolProgramTodayCard({
    super.key,
    required this.program,
    required this.date,
  });

  final AfterschoolProgram program;
  final DateTime date;

  String get _dateIso =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summary = ref.watch(afterschoolDaySummaryProvider(
        AfterschoolDayKey(programId: program.id, date: date)));

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.go(
          '/afterschool/programs/${program.id}/day/$_dateIso'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.school_outlined,
                      color: AppColors.purple, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(program.name,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        '${formatIsoWeekdaysShort(program.daysOfWeek)} · '
                        '${program.startTimeShort}–${program.endTimeShort}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.muted),
              ],
            ),
            const SizedBox(height: 12),
            summary.when(
              loading: () => const SizedBox(
                  height: 40, child: AppLoading()),
              error: (e, _) => AppError(message: e.toString()),
              data: (s) {
                if (s.isClosed) {
                  return Row(children: [
                    _pill(theme, 'ZI ÎNCHISĂ', AppColors.muted),
                    if (s.session?.closedReason != null &&
                        s.session!.closedReason!.trim().isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.session!.closedReason!,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ]);
                }
                return Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    _stat(theme, 'Așteptați', s.expectedCount,
                        color: theme.colorScheme.onSurface),
                    _stat(theme, 'Prezenți', s.presentCount,
                        color: AppColors.success),
                    _stat(theme, 'Absenți', s.absentCount,
                        color: AppColors.error),
                    _stat(theme, 'Nemarcați', s.unmarkedCount,
                        color: AppColors.warning),
                    if (s.unexpectedAttendance.isNotEmpty)
                      _stat(theme,
                          'În afara programului',
                          s.unexpectedAttendance.length,
                          color: AppColors.warning),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(ThemeData theme, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Widget _stat(ThemeData theme, String label, int value,
      {required Color color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 22,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text('$value',
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline)),
      ],
    );
  }
}
