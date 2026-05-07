import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/workshop_type_helper.dart';
import '../../domain/workshop_detail_row.dart';

class WorkshopHeaderCard extends StatelessWidget {
  const WorkshopHeaderCard({super.key, required this.row});
  final WorkshopDetailRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeColor = WorkshopTypeHelper.colorForType(row.workshopType);
    final typeIcon = WorkshopTypeHelper.iconForType(row.workshopType);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
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
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(typeIcon, color: typeColor, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.title,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    WorkshopDetailTypeBadge(
                        type: row.workshopType, color: typeColor),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              WorkshopInfoChip(
                icon: Icons.calendar_today_outlined,
                label:
                    '${row.dayOfWeek}, ${formatDate(row.workshopDate)}',
                color: AppColors.purple,
              ),
              const SizedBox(width: 10),
              WorkshopInfoChip(
                icon: Icons.access_time_rounded,
                label:
                    '${formatTimeString(row.startTime)} – ${formatTimeString(row.endTime)}',
                color: AppColors.info,
              ),
            ],
          ),
          if (row.trainerName != null) ...[
            const SizedBox(height: 10),
            WorkshopInfoChip(
              icon: Icons.person_outline,
              label: row.trainerName!,
              color: AppColors.success,
            ),
          ],
        ],
      ),
    );
  }
}

class WorkshopDetailTypeBadge extends StatelessWidget {
  const WorkshopDetailTypeBadge(
      {super.key, required this.type, required this.color});
  final String type;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        type,
        style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class WorkshopInfoChip extends StatelessWidget {
  const WorkshopInfoChip(
      {super.key,
      required this.icon,
      required this.label,
      required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
