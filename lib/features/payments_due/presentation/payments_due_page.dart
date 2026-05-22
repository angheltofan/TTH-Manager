import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../domain/payment_due_item.dart';
import '../providers/payments_due_providers.dart';

class PaymentsDuePage extends ConsumerWidget {
  const PaymentsDuePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final itemsAsync = ref.watch(paymentsDueProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/dashboard'),
        ),
        title: const Text('Plăți restante'),
      ),
      body: itemsAsync.when(
        loading: () => const AppLoading(),
        error: (e, _) => Center(child: AppError(message: e.toString())),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      size: 48, color: AppColors.success),
                  const SizedBox(height: 16),
                  Text(
                    'Nu există plăți restante.',
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _PaymentDueCard(item: items[i]),
          );
        },
      ),
    );
  }
}

// ── Payment due card ──────────────────────────────────────────────────────────

class _PaymentDueCard extends StatelessWidget {
  const _PaymentDueCard({required this.item});
  final PaymentDueItem item;

  bool get _isOverdue => item.status == 'overdue';

  Color get _statusColor => _isOverdue ? AppColors.error : AppColors.warning;

  String get _statusLabel => _isOverdue ? 'Restant' : 'De plată';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.push('/children/${item.childId}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _statusColor.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            // ── Status icon ───────────────────────────────────────────────
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _isOverdue
                    ? Icons.warning_amber_rounded
                    : Icons.payments_outlined,
                color: _statusColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),

            // ── Child name + period ───────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.fullName,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  _MetaRow(item: item),
                ],
              ),
            ),

            // ── Status badge ──────────────────────────────────────────────
            const SizedBox(width: 12),
            _StatusBadge(label: _statusLabel, color: _statusColor),

            // ── Arrow ─────────────────────────────────────────────────────
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: theme.colorScheme.outline),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.item});
  final PaymentDueItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = <String>[];

    if (item.periodStart != null && item.periodEnd != null) {
      parts.add(
          '${formatDate(item.periodStart!)} – ${formatDate(item.periodEnd!)}');
    } else if (item.periodStart != null) {
      parts.add('Din ${formatDate(item.periodStart!)}');
    }

    if (item.sessionsCount != null) {
      parts.add('${item.sessionsCount} ședințe');
    }

    if (parts.isEmpty) return const SizedBox.shrink();

    return Text(
      parts.join(' · '),
      style: theme.textTheme.bodySmall
          ?.copyWith(color: theme.colorScheme.outline),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
