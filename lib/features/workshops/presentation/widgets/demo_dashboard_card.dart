import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../demo_workshops/domain/demo_workshop.dart';
import '../../../dashboard/presentation/widgets/workshop_card_helpers.dart';

/// A card for a demo workshop shown in the "Ateliere azi" section.
/// Visually similar to [DashboardWorkshopItem] but includes the DEMO badge
/// and routes to the demo details page.
class DemoDashboardCard extends StatelessWidget {
  const DemoDashboardCard({super.key, required this.demo});
  final DemoWorkshop demo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (typeIcon, typeColor) = workshopTypeStyle(demo.workshopType);

    final status = resolveWorkshopCardStatus(
      workshopDate: demo.demoDate,
      startTime: demo.startTime,
      endTime: demo.endTime,
    );
    final (statusLabel, statusColor) = switch (status) {
      WorkshopCardStatus.ongoing => ('În desfășurare', AppColors.success),
      WorkshopCardStatus.upcoming => ('Programat', AppColors.info),
      WorkshopCardStatus.finished => ('Finalizat', theme.colorScheme.outline),
    };

    final metaParts = [
      '${formatTimeString(demo.startTime)}–${formatTimeString(demo.endTime)}',
      if (demo.trainerName != null) demo.trainerName!,
      demo.childFullName,
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.demoBadge.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.go('/demo-workshops/${demo.id}'),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color:
                      AppColors.demoBadge.withValues(alpha: 0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Type icon
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 19),
                ),
                const SizedBox(width: 12),

                // Title + meta
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              demo.workshopTitle,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          // DEMO badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.demoBadge
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Text(
                              'DEMO',
                              style: TextStyle(
                                color: AppColors.demoBadge,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (metaParts.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          metaParts.join(' · '),
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          // type badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: typeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              demo.workshopType,
                              style: TextStyle(
                                  color: typeColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          // status pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
