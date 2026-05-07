import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum BadgeStatus { present, absent, motivated, paid, due, overdue, cancelled }

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final BadgeStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: _color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            _label,
            style: TextStyle(
              color: _color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color get _color => switch (status) {
        BadgeStatus.present => AppColors.success,
        BadgeStatus.absent => AppColors.error,
        BadgeStatus.motivated => AppColors.warning,
        BadgeStatus.paid => AppColors.success,
        BadgeStatus.due => AppColors.warning,
        BadgeStatus.overdue => AppColors.error,
        BadgeStatus.cancelled => Colors.grey,
      };

  String get _label => switch (status) {
        BadgeStatus.present => 'Prezent',
        BadgeStatus.absent => 'Absent',
        BadgeStatus.motivated => 'Motivat',
        BadgeStatus.paid => 'Plătit',
        BadgeStatus.due => 'De plătit',
        BadgeStatus.overdue => 'Restanță',
        BadgeStatus.cancelled => 'Anulat',
      };
}

