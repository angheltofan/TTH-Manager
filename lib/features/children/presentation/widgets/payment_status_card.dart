import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../domain/child_payment_cycle.dart';
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
    final groups = _buildGroups(allPaymentRows, paymentCycles);

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

    // Resolve the method for an already-confirmed advance cycle.
    final advanceCycle = paymentCycles
        .where((c) => c.status == 'paid_advance')
        .firstOrNull;
    final confirmedPaymentMethod = advanceCycle != null
        ? _resolveMethod(advanceCycle.paymentMethod, advanceCycle.notes)
        : null;

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
              isConfirmed: isAlreadyConfirmed,              confirmedPaymentMethod: confirmedPaymentMethod,            ),
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
                paymentMethod: g.paymentMethod,
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
    final authUser = ref.read(currentUserProvider);
    if (authUser == null) return;
    final isStaff =
        ref.read(currentProfileProvider).valueOrNull?.isStaff ?? false;

    final result = await showPaymentMethodDialog(
      context,
      onConfirm: (method) async {
        await ref.read(childDetailsRepositoryProvider).confirmPayment(
          isStaff: isStaff,
          cycleId: cycleId,
          userId: authUser.id,
          paymentMethod: method.toLowerCase(), // 'pos' or 'op'
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

  List<CycleGroup> _buildGroups(
    List<ChildPaymentStatusRow> rows,
    List<ChildPaymentCycle> cycles,
  ) {
    final Map<String, List<ChildPaymentStatusRow>> map = {};
    final Map<String, ChildPaymentStatusRow> meta = {};

    for (final row in rows) {
      final id = row.cycleId ?? '';
      if (id.isEmpty) continue;
      map.putIfAbsent(id, () => []).add(row);
      meta.putIfAbsent(id, () => row);
    }

    // Build a lookup of cycle data for paymentMethod / notes.
    final cycleData = {for (final c in cycles) c.id: c};

    final groups = map.entries.map((e) {
      final m = meta[e.key]!;
      final sorted = (e.value
            ..sort((a, b) => (a.workshopDate ?? DateTime(0))
                .compareTo(b.workshopDate ?? DateTime(0))))
          .where((r) => r.workshopDate != null)
          .toList();
      final cycle = cycleData[e.key];
      return CycleGroup(
        cycleId: e.key,
        cycleStatus: m.cycleStatus,
        periodStart: m.periodStart,
        periodEnd: m.periodEnd,
        paidAt: m.paidAt,
        confirmedByName: m.confirmedByName,
        paymentMethod:
            _resolveMethod(cycle?.paymentMethod, cycle?.notes),
        rows: sorted,
      );
    }).toList();

    // Defensive: make sure every due/overdue cycle is represented, even when
    // the rows view returns no attendance rows for it (trigger race, partial
    // linking, etc.). Without this, a freshly-closed cycle could disappear
    // from "Status plată" and the user would lose the confirm-payment action.
    final represented = map.keys.toSet();
    for (final cycle in cycles) {
      if (cycle.id.isEmpty) continue;
      if (represented.contains(cycle.id)) continue;
      if (cycle.status != 'due' && cycle.status != 'overdue') continue;
      groups.add(CycleGroup(
        cycleId: cycle.id,
        cycleStatus: cycle.status,
        periodStart: cycle.periodStart,
        periodEnd: cycle.periodEnd,
        paidAt: cycle.paidAt,
        confirmedByName: null,
        paymentMethod: _resolveMethod(cycle.paymentMethod, cycle.notes),
        rows: const [],
      ));
    }

    return groups;
  }

  /// Derives a display method label from the stored column or, as fallback,
  /// the legacy notes string written by older versions of the app.
  static String? _resolveMethod(String? paymentMethod, String? notes) {
    if (paymentMethod != null && paymentMethod.isNotEmpty) {
      return paymentMethod.toUpperCase(); // 'pos' → 'POS', 'op' → 'OP'
    }
    if (notes == null) return null;
    final upper = notes.toUpperCase();
    if (upper.contains('POS')) return 'POS';
    // 'OP' was written as "... prin OP." — avoid matching it inside longer words.
    if (RegExp(r'\bOP\b').hasMatch(upper)) return 'OP';
    return null;
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
