import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/dashboard_workshop.dart';
import 'today_workshop_card.dart';

/// Renders the list of today's workshops, or an empty-state message.
/// Set [scrollable] to true for the wide/desktop layout inside an expanded SectionCard.
class WorkshopsTodayList extends StatelessWidget {
  const WorkshopsTodayList({
    super.key,
    required this.workshops,
    required this.currentUserId,
    this.scrollable = false,
  });

  final List<DashboardWorkshop> workshops;
  final String? currentUserId;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (workshops.isEmpty) {
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

    if (scrollable) {
      return ListView.builder(
        padding: EdgeInsets.zero,
        physics: const ClampingScrollPhysics(),
        itemCount: workshops.length,
        itemBuilder: (context, i) => TodayWorkshopCard(
          workshop: workshops[i],
          isOwn: currentUserId != null &&
              workshops[i].trainerId == currentUserId,
        ),
      );
    }

    return Column(
      children: [
        for (final w in workshops)
          TodayWorkshopCard(
            workshop: w,
            isOwn: currentUserId != null && w.trainerId == currentUserId,
          ),
      ],
    );
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
