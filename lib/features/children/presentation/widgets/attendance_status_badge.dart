import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Coloured pill badge for an attendance status value.
/// Accepts 'present', 'absent', 'motivated', or null.
class AttendanceStatusBadge extends StatelessWidget {
  const AttendanceStatusBadge({super.key, required this.status});
  final String? status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'present' => (AppColors.success, 'Prezent'),
      'absent' => (AppColors.error, 'Absent'),
      'motivated' => (AppColors.warning, 'Motivat'),
      _ => (AppColors.muted, 'Nemarcat'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// Coloured pill badge for a payment cycle status.
/// Accepts 'paid', 'paid_advance', 'due', 'overdue', 'cancelled'.
class PaymentStatusBadge extends StatelessWidget {
  const PaymentStatusBadge({super.key, required this.status});
  final String? status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'paid' => (AppColors.success, 'Achitat'),
      'paid_advance' => (AppColors.info, 'Achitat în avans'),
      'due' => (AppColors.warning, 'Neplătit'),
      'overdue' => (AppColors.error, 'Restant'),
      'cancelled' => (AppColors.muted, 'Anulat'),
      _ => (AppColors.muted, status ?? '—'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
