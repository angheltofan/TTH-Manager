import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/child_current_status_row.dart';
import '../../providers/child_details_providers.dart';
import 'attendance_row_item.dart';
import 'payment_dialog.dart';
import 'payment_status_helpers.dart';

class ActiveCycleSection extends ConsumerStatefulWidget {
  const ActiveCycleSection({
    super.key,
    required this.childId,
    required this.currentRows,
    required this.dueGroup,
    required this.isConfirmed,
  });

  final String childId;
  final List<ChildCurrentStatusRow> currentRows;
  final CycleGroup? dueGroup;
  final bool isConfirmed;

  @override
  ConsumerState<ActiveCycleSection> createState() => _ActiveCycleSectionState();
}

class _ActiveCycleSectionState extends ConsumerState<ActiveCycleSection> {
  bool _confirmedLocally = false;

  bool get _showAsConfirmed => widget.isConfirmed || _confirmedLocally;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = widget.currentRows;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Title row ──────────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: Text(
                'Ciclu activ',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (_showAsConfirmed)
              const ConfirmedBadge()
            else
              FilledButton(
                onPressed: _onConfirm,
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
                child: const Text('Confirmă plata'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _showAsConfirmed
              ? 'Plata a fost confirmată pentru ședințele de mai jos.'
              : widget.dueGroup != null
                  ? 'Confirmați plata pentru ciclul curent.'
                  : 'Marchează plata în avans pentru ședințele de mai jos.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
        const SizedBox(height: 12),
        // ── Attendance rows ───────────────────────────────────────────────
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
    );
  }

  Future<void> _onConfirm() async {
    final authUser = Supabase.instance.client.auth.currentUser;
    if (authUser == null) return;

    final isDue = widget.dueGroup != null;
    final repo = ref.read(childDetailsRepositoryProvider);

    final result = await showPaymentMethodDialog(
      context,
      onConfirm: (method) async {
        final notes = 'Plată confirmată prin $method.';
        if (isDue) {
          await repo.confirmPayment(
            cycleId: widget.dueGroup!.cycleId,
            userId: authUser.id,
            notes: notes,
          );
        } else {
          await repo.markAdvancePayment(
            childId: widget.childId,
            currentUserId: authUser.id,
            notes: notes,
          );
        }
      },
    );

    if (result == null) return;

    if (isDue) {
      ref.invalidate(childPaymentStatusRowsProvider(widget.childId));
      ref.invalidate(childPaymentCyclesNewProvider(widget.childId));
      ref.invalidate(childCurrentStatusRowsProvider(widget.childId));
      ref.invalidate(childCurrentStatusProvider(widget.childId));
    } else {
      ref.invalidate(childPaymentStatusRowsProvider(widget.childId));
      ref.invalidate(childPaymentCyclesNewProvider(widget.childId));
      if (mounted) setState(() => _confirmedLocally = true);
    }
  }
}
