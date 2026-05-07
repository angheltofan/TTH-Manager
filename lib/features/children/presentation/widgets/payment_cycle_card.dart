import 'package:flutter/material.dart';

import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/responsive.dart';
import '../../domain/child_payment_status_row.dart';
import 'attendance_row_item.dart';

/// Renders one payment cycle with its attendance rows.
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
  final Future<void> Function()? onConfirmPayment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = context.isMobile;

    final (statusColor, statusLabel) = switch (cycleStatus) {
      'paid' => (const Color(0xFF22C55E), 'Plătit'),
      'paid_advance' => (const Color(0xFF3B82F6), 'Plătit'),
      'due' => (const Color(0xFFF59E0B), 'De plată'),
      'overdue' => (const Color(0xFFEF4444), 'Restant'),
      'cancelled' => (const Color(0xFF94A3B8), 'Anulat'),
      _ => (const Color(0xFF94A3B8), cycleStatus ?? '—'),
    };

    final cycleTitle =
        cycleNumber != null ? 'Ciclu de plată #$cycleNumber' : 'Ciclu de plată';

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
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + status badge (+ confirm button on desktop)
                if (isMobile) ...[
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Text(
                        cycleTitle,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      _StatusPill(label: statusLabel, color: statusColor),
                      if (onConfirmPayment != null)
                        _ConfirmButton(onConfirm: onConfirmPayment!),
                    ],
                  ),
                ] else ...[
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
                            _StatusPill(label: statusLabel, color: statusColor),
                          ],
                        ),
                      ),
                      if (onConfirmPayment != null)
                        _ConfirmButton(onConfirm: onConfirmPayment!),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                // Meta info – wrap on mobile
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (periodStart != null && periodEnd != null)
                      _MetaChip(
                        icon: Icons.calendar_today_outlined,
                        text:
                            '${formatDate(periodStart!)} – ${formatDate(periodEnd!)}',
                        theme: theme,
                      ),
                    _MetaChip(
                      icon: Icons.groups_outlined,
                      text: '${rows.length} ședințe',
                      theme: theme,
                    ),
                    if (paidAt != null)
                      _MetaChip(
                        icon: Icons.check_circle_outline,
                        text: 'Plătit la: ${formatDate(paidAt!)}'
                            '${confirmedByName != null ? ' de $confirmedByName' : ''}',
                        theme: theme,
                      )
                    else if (cycleStatus == 'due' || cycleStatus == 'overdue')
                      _MetaChip(
                        icon: Icons.warning_amber_rounded,
                        text: 'Scadentă',
                        theme: theme,
                        color: statusColor,
                      ),
                  ],
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

          // Attendance rows
          if (rows.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Column(
                children: [
                  const AttendanceTableHeader(),
                  for (int i = 0; i < rows.length; i++)
                    AttendanceRowItem(
                      index: i + 1,
                      workshopTitle: rows[i].workshopTitle ?? '—',
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
                'Nu există prezențe înregistrate pentru acest ciclu.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Meta chip ─────────────────────────────────────────────────────────────────

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.text,
    required this.theme,
    this.color,
  });
  final IconData icon;
  final String text;
  final ThemeData theme;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? theme.colorScheme.onSurface.withValues(alpha: 0.55);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: c),
        const SizedBox(width: 4),
        Text(text,
            style: theme.textTheme.bodySmall!
                .copyWith(color: c, fontSize: 11, fontWeight: color != null ? FontWeight.w600 : null)),
      ],
    );
  }
}

// ── Confirm payment button ────────────────────────────────────────────────────

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
        textStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      child: _loading
          ? const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : const Text('Confirmă plata'),
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

// ── Status pill ───────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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