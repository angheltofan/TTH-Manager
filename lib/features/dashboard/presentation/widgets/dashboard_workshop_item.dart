import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../domain/dashboard_workshop.dart';
import 'workshop_card_helpers.dart';

/// A unified workshop card used in both "Ateliere azi" and "Toate atelierele".
/// Identical typography, badges, spacing, and status display in both sections.
///
/// - Set [showDate] = true in the "all workshops" list to include the date.
/// - Set [isOwn] = true when the workshop belongs to the logged-in trainer.
class DashboardWorkshopItem extends StatelessWidget {
  const DashboardWorkshopItem({
    super.key,
    required this.workshop,
    this.isOwn = false,
    this.showDate = false,
  });

  final DashboardWorkshop workshop;
  final bool isOwn;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = resolveWorkshopCardStatus(
      workshopDate: workshop.workshopDate,
      startTime: workshop.startTime,
      endTime: workshop.endTime,
    );
    final (statusLabel, statusColor) = switch (status) {
      WorkshopCardStatus.ongoing => ('În desfășurare', AppColors.success),
      WorkshopCardStatus.upcoming => ('Programat', AppColors.info),
      WorkshopCardStatus.finished => ('Finalizat', theme.colorScheme.outline),
    };
    final (typeIcon, typeColor) = workshopTypeStyle(workshop.workshopType);

    final metaParts = [
      if (showDate) formatDate(workshop.workshopDate),
      '${formatTimeString(workshop.startTime)}–${formatTimeString(workshop.endTime)}',
      if (workshop.trainerName != null) workshop.trainerName!,
      if (workshop.childrenCount != null && workshop.childrenCount! > 0)
        '${workshop.childrenCount} copii',
    ];

    return Material(
      color: isOwn
          ? theme.colorScheme.primary.withValues(alpha: 0.06)
          : theme.cardTheme.color,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.go('/workshops/${workshop.id}'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isOwn
                  ? theme.colorScheme.primary.withValues(alpha: 0.4)
                  : theme.colorScheme.outline.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Type icon ──────────────────────────────────────────────
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

              // ── Title + meta ───────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            workshop.title,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isOwn) ...[
                          const SizedBox(width: 6),
                          const WorkshopOwnBadge(),
                        ],
                      ],
                    ),
                    if (metaParts.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        metaParts.join(' · '),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 5),
                    // ── Type badge ─────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: typeColor.withValues(alpha: 0.25)),
                      ),
                      child: Text(
                        workshop.workshopType,
                        style: TextStyle(
                          color: typeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // ── Status pill ────────────────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
