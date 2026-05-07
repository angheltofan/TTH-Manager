import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../providers/dashboard_providers.dart';
import 'dashboard_workshop_item.dart';

/// Scrollable card listing all scheduled workshops ordered by date and time.
class AllWorkshopsCard extends ConsumerWidget {
  const AllWorkshopsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final allAsync = ref.watch(allScheduledWorkshopsProvider);
    final isAdmin =
        ref.watch(currentProfileProvider).valueOrNull?.isAdmin ?? false;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Toate atelierele',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                allAsync.maybeWhen(
                  data: (ws) => ws.isNotEmpty
                      ? _CountBadge(count: ws.length)
                      : const SizedBox.shrink(),
                  orElse: () => const SizedBox.shrink(),
                ),
                if (isAdmin) ...[  
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_rounded),
                    tooltip: 'Adaugă atelier',
                    color: AppColors.purple,
                    onPressed: () => context.go('/workshops/new'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: allAsync.when(
              loading: () => const Center(child: AppLoading()),
              error: (e, _) => Center(child: AppError(message: e.toString())),
              data: (workshops) {
                if (workshops.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_busy_outlined,
                            color: theme.colorScheme.outline, size: 32),
                        const SizedBox(height: 10),
                        Text(
                          'Nu există ateliere programate.',
                          style: TextStyle(
                              color: theme.colorScheme.outline, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  itemCount: workshops.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: DashboardWorkshopItem(
                      workshop: workshops[i],
                      showDate: true,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.purple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: AppColors.purple,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

