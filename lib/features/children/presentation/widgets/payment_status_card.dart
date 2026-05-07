import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../domain/child_payment_status_row.dart';
import '../../providers/child_details_providers.dart';
import 'active_cycle_section.dart';
import 'details_section_card.dart';
import 'payment_cycle_card.dart';
import 'payment_dialog.dart';
import 'payment_status_helpers.dart';

// ── PaymentStatusCard ─────────────────────────────────────────────────────────

class PaymentStatusCard extends ConsumerWidget {
  const PaymentStatusCard({super.key, required this.childId});
  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final paymentRowsAsync = ref.watch(childPaymentStatusRowsProvider(childId));
    final currentRowsAsync = ref.watch(childCurrentStatusRowsProvider(childId));
    final paymentCyclesAsync =
        ref.watch(childPaymentCyclesNewProvider(childId));

    if (paymentRowsAsync.isLoading || currentRowsAsync.isLoading) {
      return const DetailsSectionCard(
        title: 'Status plată',
        iconData: Icons.credit_card_rounded,
        iconColor: Color(0xFF3B82F6),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: AppLoading(),
        ),
      );
    }

    if (paymentRowsAsync.hasError) {
      return DetailsSectionCard(
        title: 'Status plată',
        iconData: Icons.credit_card_rounded,
        iconColor: const Color(0xFF3B82F6),
        child: AppError(message: paymentRowsAsync.error.toString()),
      );
    }

    final allPaymentRows = paymentRowsAsync.valueOrNull ?? [];
    final currentRows = currentRowsAsync.valueOrNull ?? [];
    final paymentCycles = paymentCyclesAsync.valueOrNull ?? [];
    final groups = _buildGroups(allPaymentRows);

    final sortedAsc = [...groups]
      ..sort((a, b) => (a.periodStart ?? DateTime(0))
          .compareTo(b.periodStart ?? DateTime(0)));
    final cycleNumbers = {
      for (var i = 0; i < sortedAsc.length; i++) sortedAsc[i].cycleId: i + 1
    };

    final dueGroups = groups
        .where((g) => g.cycleStatus == 'due' || g.cycleStatus == 'overdue')
        .toList();
    final paidGroups = groups.where((g) => g.cycleStatus == 'paid').toList();

    final isAlreadyConfirmed =
        paymentCycles.any((c) => c.status == 'paid_advance') ||
            groups.any((g) => g.cycleStatus == 'paid_advance');

    final dueGroup = dueGroups.isNotEmpty ? dueGroups.first : null;
    final showActiveCycle = currentRows.isNotEmpty;
    final visible =
        _buildVisible(groups, hasCurrentRows: currentRows.isNotEmpty);

    return DetailsSectionCard(
      title: 'Status plată',
      iconData: Icons.credit_card_rounded,
      iconColor: const Color(0xFF3B82F6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Active cycle section ─────────────────────────────────────────
          if (showActiveCycle) ...[
            ActiveCycleSection(
              childId: childId,
              currentRows: currentRows,
              dueGroup: dueGroup,
              isConfirmed: isAlreadyConfirmed,
            ),
            if (visible.isNotEmpty)
              Divider(
                height: 24,
                thickness: 1,
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.15),
              ),
          ],

          // ── Past / due cycles ────────────────────────────────────────────
          if (!showActiveCycle && groups.isEmpty)
            Text(
              'Nu există încă un status de plată.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            )
          else if (visible.isNotEmpty) ...[
            if (dueGroups.isNotEmpty)
              SummaryBanner(
                dueCount: dueGroups.length,
                paidCount: paidGroups.length,
              ),
            ...visible.map(
              (g) => PaymentCycleCard(
                cycleId: g.cycleId,
                cycleNumber: cycleNumbers[g.cycleId],
                cycleStatus: g.cycleStatus,
                periodStart: g.periodStart,
                periodEnd: g.periodEnd,
                paidAt: g.paidAt,
                confirmedByName: g.confirmedByName,
                rows: g.rows,
                onConfirmPayment:
                    (g.cycleStatus == 'due' || g.cycleStatus == 'overdue')
                        ? () => _confirmClosedCycle(context, ref, g.cycleId)
                        : null,
              ),
            ),
            if (dueGroups.isNotEmpty) const InfoNote(),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmClosedCycle(
      BuildContext context, WidgetRef ref, String cycleId) async {
    final authUser = Supabase.instance.client.auth.currentUser;
    if (authUser == null) return;

    final result = await showPaymentMethodDialog(
      context,
      onConfirm: (method) async {
        await ref.read(childDetailsRepositoryProvider).confirmPayment(
          cycleId: cycleId,
          userId: authUser.id,
          notes: 'Plată confirmată prin $method.',
        );
      },
    );
    if (result == null || !context.mounted) return;

    ref.invalidate(childPaymentStatusRowsProvider(childId));
    ref.invalidate(childPaymentCyclesNewProvider(childId));
    ref.invalidate(childCurrentStatusRowsProvider(childId));
    ref.invalidate(childCurrentStatusProvider(childId));
  }

  List<CycleGroup> _buildGroups(List<ChildPaymentStatusRow> rows) {
    final Map<String, List<ChildPaymentStatusRow>> map = {};
    final Map<String, ChildPaymentStatusRow> meta = {};

    for (final row in rows) {
      final id = row.cycleId ?? '';
      if (id.isEmpty) continue;
      map.putIfAbsent(id, () => []).add(row);
      meta.putIfAbsent(id, () => row);
    }

    return map.entries.map((e) {
      final m = meta[e.key]!;
      final sorted = (e.value
            ..sort((a, b) => (a.workshopDate ?? DateTime(0))
                .compareTo(b.workshopDate ?? DateTime(0))))
          .where((r) => r.workshopDate != null)
          .toList();
      return CycleGroup(
        cycleId: e.key,
        cycleStatus: m.cycleStatus,
        periodStart: m.periodStart,
        periodEnd: m.periodEnd,
        paidAt: m.paidAt,
        confirmedByName: m.confirmedByName,
        rows: sorted,
      );
    }).toList();
  }

  List<CycleGroup> _buildVisible(List<CycleGroup> groups,
      {required bool hasCurrentRows}) {
    final unpaid = groups
        .where((g) => g.cycleStatus == 'due' || g.cycleStatus == 'overdue')
        .toList();
    if (unpaid.isNotEmpty) return unpaid;

    if (!hasCurrentRows) {
      final advance =
          groups.where((g) => g.cycleStatus == 'paid_advance').toList();
      if (advance.isNotEmpty) return advance;
    }

    final paid = groups
        .where((g) => g.cycleStatus == 'paid')
        .toList()
      ..sort((a, b) => (b.periodStart ?? DateTime(0))
          .compareTo(a.periodStart ?? DateTime(0)));
    return paid.isNotEmpty ? [paid.first] : [];
  }
}


class _CycleGroup {
  const _CycleGroup({
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

// ── Payment method dialog ────────────────────────────────────────────────────
//
// A StatefulWidget dialog that:
//   • Shows POS / OP radio options
//   • Displays a loading spinner on its own "Confirmă" button while calling
//     [onConfirm] — the dialog never freezes or blocks the page behind it
//   • Closes on success (pops with the selected method string)
//   • Shows an inline error message and resets loading on failure so the user
//     can retry or cancel without leaving the page

Future<String?> _showPaymentMethodDialog(
  BuildContext context, {
  required Future<void> Function(String method) onConfirm,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PaymentDialog(onConfirm: onConfirm),
  );
}

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({required this.onConfirm});
  final Future<void> Function(String method) onConfirm;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  String _selected = 'POS';
  bool _loading = false;
  String? _errorText;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirmare plată'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Alege metoda de plată.'),
          const SizedBox(height: 8),
          RadioListTile<String>(
            value: 'POS',
            groupValue: _selected,
            title: const Text('POS'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            onChanged:
                _loading ? null : (v) => setState(() => _selected = v!),
          ),
          RadioListTile<String>(
            value: 'OP',
            groupValue: _selected,
            title: const Text('OP'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            onChanged:
                _loading ? null : (v) => setState(() => _selected = v!),
          ),
          if (_errorText != null) ...[  
            const SizedBox(height: 8),
            Text(
              _errorText!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed:
              _loading ? null : () => Navigator.of(context).pop(null),
          child: const Text('Anulează'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Confirmă'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      await widget.onConfirm(_selected);
      if (mounted) Navigator.of(context).pop(_selected);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorText = 'Eroare la confirmare. Încearcă din nou.';
        });
      }
    }
  }
}
