import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../afterschool/domain/afterschool_child_history.dart';
import '../../../../afterschool/providers/afterschool_providers.dart';
import 'afterschool_child_history_row.dart';
import 'current_tab.dart' show CompletedCycleAccordion;
import 'series_snapshot.dart';

/// "Istoric" tab: workshop series with their cycles + Afterschool
/// programs with monthly periods.
///
/// Afterschool side is **enrollment-driven**, not payment-row-driven:
/// a month covered by any of the child's enrollments shows up even
/// when no `afterschool_monthly_payments` row exists yet. The
/// unmaterialised months render a "Plată neînregistrată" pill plus an
/// admin "Înregistrează luna" button (via `buildAfterschoolChildHistory`
/// + `AfterschoolChildHistoryRow`).
class HistoryTab extends ConsumerWidget {
  const HistoryTab({
    super.key,
    required this.childId,
    required this.snapshots,
  });

  final String childId;
  final Map<String, SeriesFinancialSnapshot> snapshots;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final orderedWorkshops = snapshots.values
        .where((s) => s.allCycles.isNotEmpty)
        .toList()
      ..sort((a, b) => a.seriesTitle.compareTo(b.seriesTitle));

    final enrollments =
        ref.watch(afterschoolEnrollmentsForChildProvider(childId)).valueOrNull ??
            const [];
    final allPrograms =
        ref.watch(afterschoolAllProgramsProvider).valueOrNull ?? const [];

    // Afterschool history is attendance-only (approved product UX).
    final afterschoolBlocks = buildAfterschoolChildHistory(
      enrollments: enrollments,
      allPrograms: allPrograms,
      today: DateTime.now(),
    );

    if (orderedWorkshops.isEmpty && afterschoolBlocks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Nu există istoric de cicluri pentru acest copil.',
            style: TextStyle(color: AppColors.muted),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var s = 0; s < orderedWorkshops.length; s++) ...[
          if (s > 0) const SizedBox(height: 20),
          Text(
            orderedWorkshops[s].seriesTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.purple,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = orderedWorkshops[s].allCycles.length - 1; i >= 0; i--) ...[
            CompletedCycleAccordion(
              childId: childId,
              snapshot: orderedWorkshops[s],
              cycleIndex: i,
              cycleNumber: i + 1,
            ),
            const SizedBox(height: 8),
          ],
        ],
        if (afterschoolBlocks.isNotEmpty) ...[
          if (orderedWorkshops.isNotEmpty) const SizedBox(height: 20),
          for (var i = 0; i < afterschoolBlocks.length; i++) ...[
            if (i > 0) const SizedBox(height: 20),
            Text(
              '${afterschoolBlocks[i].program.name} · Afterschool',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.purple,
              ),
            ),
            const SizedBox(height: 8),
            for (final entry in afterschoolBlocks[i].entries) ...[
              AfterschoolChildHistoryRow(
                childId: childId,
                program: afterschoolBlocks[i].program,
                year: entry.year,
                month: entry.month,
              ),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ],
    );
  }
}
