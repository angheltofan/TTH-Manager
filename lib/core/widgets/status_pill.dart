import 'package:flutter/material.dart';

/// Canonical coloured pill used for every "status" surface across the
/// app (attendance status, payment status, primary/secondary badges,
/// etc.). Single visual recipe — same alphas, radius, font size and
/// font weight as the staff `AttendanceStatusBadge` and
/// `PaymentStatusBadge`. Callers supply the resolved `(label, color)`
/// and choose whether to render the outline border.
///
/// Recipe:
///   • padding: 10 × 4
///   • radius:  20
///   • background: `color α 0.13`
///   • border:     `color α 0.4` when [hasBorder] is true (default)
///   • text: 12 / w700 / [color]
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.hasBorder = true,
  });

  final String label;
  final Color color;

  /// When false the pill renders without the outline border (matches
  /// the staff `_PrimaryBadge` recipe on the Child Details page).
  final bool hasBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
        border: hasBorder
            ? Border.all(color: color.withValues(alpha: 0.4))
            : null,
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
