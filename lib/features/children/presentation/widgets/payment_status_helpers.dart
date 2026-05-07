import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/child_payment_status_row.dart';

// ── Cycle group ───────────────────────────────────────────────────────────────

class CycleGroup {
  const CycleGroup({
    required this.cycleId,
    required this.cycleStatus,
    this.periodStart,
    this.periodEnd,
    this.paidAt,
    this.confirmedByName,
    required this.rows,
  });

  final String cycleId;
  final String? cycleStatus;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final DateTime? paidAt;
  final String? confirmedByName;
  final List<ChildPaymentStatusRow> rows;
}

// ── Confirmed badge ───────────────────────────────────────────────────────────

class ConfirmedBadge extends StatelessWidget {
  const ConfirmedBadge({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.30)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline_rounded,
                size: 14, color: AppColors.success),
            SizedBox(width: 6),
            Text(
              'Plată confirmată',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}

// ── Summary banner ────────────────────────────────────────────────────────────

class SummaryBanner extends StatelessWidget {
  const SummaryBanner({
    super.key,
    required this.dueCount,
    required this.paidCount,
  });

  final int dueCount;
  final int paidCount;

  @override
  Widget build(BuildContext context) {
    final dueStr =
        dueCount == 1 ? '1 ciclu de plată' : '$dueCount cicluri de plată';
    final paidStr =
        paidCount == 1 ? '1 ciclu achitat' : '$paidCount cicluri achitate';
    final text =
        'Ai $dueStr în așteptare${paidCount > 0 ? ' și $paidStr' : ''}.';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info note ─────────────────────────────────────────────────────────────────

class InfoNote extends StatelessWidget {
  const InfoNote({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 14, color: theme.colorScheme.outline),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'După confirmarea plății, ciclul va fi marcat ca achitat.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ),
        ],
      ),
    );
  }
}
