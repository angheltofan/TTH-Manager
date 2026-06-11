import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/section_card.dart';
import '../../domain/parent_dashboard.dart';
import 'parent_recent_activity_card.dart';
import 'parent_weekly_schedule_card.dart';

/// Two-column "Program săptămâna aceasta" + "Activitate recentă"
/// section at the bottom of the parent dashboard. Stacks vertically on
/// narrow screens. The two columns are wrapped in `IntrinsicHeight` so
/// the section's height matches the taller card.
class ParentActivityAndScheduleSection extends StatelessWidget {
  const ParentActivityAndScheduleSection({
    super.key,
    required this.recentAsync,
    required this.scheduleAsync,
    required this.showChildLabels,
    required this.isWide,
  });

  final AsyncValue<List<ParentRecentActivityItem>> recentAsync;
  final AsyncValue<List<ParentWeeklySession>> scheduleAsync;
  final bool showChildLabels;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final schedule = _ScheduleWell(
      scheduleAsync: scheduleAsync,
      showChildNames: showChildLabels,
    );
    final activity = _ActivityWell(
      recentAsync: recentAsync,
      showChildName: showChildLabels,
    );

    if (isWide) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: schedule),
            const SizedBox(width: 20),
            Expanded(child: activity),
          ],
        ),
      );
    }
    return Column(
      children: [
        schedule,
        const SizedBox(height: 20),
        activity,
      ],
    );
  }
}

class _ActivityWell extends StatelessWidget {
  const _ActivityWell({
    required this.recentAsync,
    required this.showChildName,
  });
  final AsyncValue<List<ParentRecentActivityItem>> recentAsync;
  final bool showChildName;

  @override
  Widget build(BuildContext context) {
    return recentAsync.when(
      loading: () => const SectionCard(
        title: 'Activitate recentă',
        padding: EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: SizedBox(height: 80, child: AppLoading()),
      ),
      error: (e, _) {
        if (kDebugMode) {
          debugPrint('[Parent/Activity] load failed: $e');
        }
        return const SectionCard(
          title: 'Activitate recentă',
          padding: EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: AppError(message: 'Eroare la încărcare.'),
        );
      },
      data: (items) => ParentRecentActivityCard(
        items: items,
        showChildName: showChildName,
      ),
    );
  }
}

class _ScheduleWell extends StatelessWidget {
  const _ScheduleWell({
    required this.scheduleAsync,
    required this.showChildNames,
  });
  final AsyncValue<List<ParentWeeklySession>> scheduleAsync;
  final bool showChildNames;

  @override
  Widget build(BuildContext context) {
    return scheduleAsync.when(
      loading: () => const SectionCard(
        title: 'Program săptămâna aceasta',
        padding: EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: SizedBox(height: 80, child: AppLoading()),
      ),
      error: (e, _) {
        if (kDebugMode) {
          debugPrint('[Parent/Schedule] load failed: $e');
        }
        return const SectionCard(
          title: 'Program săptămâna aceasta',
          padding: EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: AppError(message: 'Eroare la încărcare.'),
        );
      },
      data: (sessions) => ParentWeeklyScheduleCard(
        sessions: sessions,
        showChildNames: showChildNames,
      ),
    );
  }
}
