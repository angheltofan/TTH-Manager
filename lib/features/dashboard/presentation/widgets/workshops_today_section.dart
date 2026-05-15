import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../demo_workshops/domain/demo_workshop.dart';
import '../../../workshops/presentation/widgets/demo_dashboard_card.dart';
import '../../domain/dashboard_workshop.dart';
import 'today_workshop_card.dart';

/// Renders the list of today's workshops (regular + demos), or an empty-state.
/// Set [scrollable] to true for the wide/desktop layout inside an expanded SectionCard.
class WorkshopsTodayList extends StatelessWidget {
  const WorkshopsTodayList({
    super.key,
    required this.workshops,
    required this.currentUserId,
    this.demos = const [],
    this.scrollable = false,
  });

  final List<DashboardWorkshop> workshops;
  final String? currentUserId;
  final List<DemoWorkshop> demos;
  final bool scrollable;

  int get _totalCount => workshops.length + demos.length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_totalCount == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.event_busy_outlined,
                  color: theme.colorScheme.outline, size: 18),
              const SizedBox(width: 8),
              Text(
                'Nu există ateliere programate azi.',
                style: TextStyle(
                    color: theme.colorScheme.outline, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    // Build merged list: regular workshops first, then demos, both sorted by start_time.
    // Simple approach: interleave by start_time string (HH:MM:SS lexicographic ≡ time order).
    final items = <Widget>[
      for (final w in workshops)
        TodayWorkshopCard(
          workshop: w,
          isOwn: currentUserId != null && w.trainerId == currentUserId,
        ),
      for (final d in demos) DemoDashboardCard(demo: d),
    ];

    if (scrollable) {
      return ListView.builder(
        padding: EdgeInsets.zero,
        physics: const ClampingScrollPhysics(),
        itemCount: items.length,
        itemBuilder: (_, i) => items[i],
      );
    }

    return Column(children: items);
  }
}

/// Count pill shown next to the section title.
class WorkshopsCountBadge extends StatelessWidget {
  const WorkshopsCountBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.purple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: AppColors.purple,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
