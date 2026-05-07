import 'package:flutter/material.dart';

import '../../../../core/utils/date_utils.dart';
import '../../domain/child_payment_status_row.dart';
import 'attendance_row_item.dart';

/// Renders one payment cycle with its attendance rows.
/// All cycle metadata is passed as explicit fields derived from the grouped
/// [ChildPaymentStatusRow] list â€” no separate payment cycle object needed.
class PaymentCycleCard extends StatelessWidget {
  const PaymentCycleCard({
    super.key,
    this.cycleId,
    this.cycleNumber,
    this.cycleStatus,
    this.periodStart,
    this.periodEnd,
    this.paidAt,
    this.confirmedByName,
    required this.rows,
    this.onConfirmPayment,
  });

  final String? cycleId;
  final int? cycleNumber;
  final String? cycleStatus;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final DateTime? paidAt;
  final String? confirmedByName;
  final List<ChildPaymentStatusRow> rows;

  /// Non-null when a confirm button should be shown (due/overdue cycles).
  final Future<void> Function()? onConfirmPayment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (statusColor, statusLabel) = switch (cycleStatus) {
      'paid' => (const Color(0xFF22C55E), 'Plătit'),
      'paid_advance' => (const Color(0xFF3B82F6), 'Plătit'),
      'due' => (const Color(0xFFF59E0B), 'De plată'),
      'overdue' => (const Color(0xFFEF4444), 'Restant'),
      'cancelled' => (const Color(0xFF94A3B8), 'Anulat'),
      _ => (const Color(0xFF94A3B8), cycleStatus ?? 'â€”'),
    };

    final cycleTitle = cycleNumber != null
        ? 'Ciclu de platÄƒ #$cycleNumber'
        : 'Ciclu de platÄƒ';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // â”€â”€ Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            cycleTitle,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 8),
                          _StatusPill(
                              label: statusLabel, color: statusColor),
                        ],
                      ),
                    ),
                    if (onConfirmPayment != null)
                      _ConfirmButton(onConfirm: onConfirmPayment!),
                  ],
                ),
                const SizedBox(height: 6),
                // Meta row
                DefaultTextStyle(
                  style: theme.textTheme.bodySmall!.copyWith(
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.55),
                    fontSize: 11,
                  ),
                  child: Row(
                    children: [
                      if (periodStart != null && periodEnd != null) ...[
                        const Icon(Icons.calendar_today_outlined,
                            size: 12),
                        const SizedBox(width: 4),
                        Text(
                            '${formatDate(periodStart!)} â€“ ${formatDate(periodEnd!)}'),
                        const SizedBox(width: 12),
                      ],
                      Icon(Icons.groups_outlined,
                          size: 12,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.55)),
                      const SizedBox(width: 4),
                      Text('${rows.length} È™edinÈ›e'),
                      const Spacer(),
                      if (paidAt != null)
                        Text(
                          'PlÄƒtit la: ${formatDate(paidAt!)}'
                          '${confirmedByName != null ? ' de $confirmedByName' : ''}',
                        )
                      else if (cycleStatus == 'due' ||
                          cycleStatus == 'overdue')
                        Text(
                          'ScadentÄƒ',
                          style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),

          Divider(
            height: 1,
            thickness: 1,
            color: theme.colorScheme.outline.withValues(alpha: 0.12),
          ),

          // â”€â”€ Attendance table â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          if (rows.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Column(
                children: [
                  const AttendanceTableHeader(),
                  for (int i = 0; i < rows.length; i++)
                    AttendanceRowItem(
                      index: i + 1,
                      workshopTitle: rows[i].workshopTitle ?? 'â€”',
                      dayOfWeek: rows[i].dayOfWeek,
                      workshopDate: rows[i].workshopDate,
                      startTime: rows[i].startTime,
                      endTime: rows[i].endTime,
                      attendanceStatus: rows[i].attendanceStatus,
                      observation: rows[i].observation,
                    ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Text(
                'Nu existÄƒ prezenÈ›e Ã®nregistrate pentru acest ciclu.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ),
        ],
      ),
    );
  }
}

// â”€â”€ Confirm payment button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ConfirmButton extends StatefulWidget {
  const _ConfirmButton({required this.onConfirm});
  final Future<void> Function() onConfirm;

  @override
  State<_ConfirmButton> createState() => _ConfirmButtonState();
}

class _ConfirmButtonState extends State<_ConfirmButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: _loading ? null : _onPressed,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600),
      ),
      child: _loading
          ? const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : const Text('ConfirmÄƒ plata'),
    );
  }

  Future<void> _onPressed() async {
    setState(() => _loading = true);
    try {
      await widget.onConfirm();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// â”€â”€ Status pill â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      );
}
