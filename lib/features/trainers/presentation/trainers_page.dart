import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../providers/trainers_providers.dart';
import 'widgets/trainer_card.dart';

class TrainersPage extends ConsumerWidget {
  const TrainersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trainersAsync = ref.watch(trainersListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PageHeader(theme: theme),
          Expanded(
            child: trainersAsync.when(
              data: (trainers) => trainers.isEmpty
                  ? const AppEmptyState(
                      message: 'Nu există utilizatori înregistrați.',
                      icon: Icons.people_outlined,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: trainers.length,
                      itemBuilder: (context, index) =>
                          TrainerCard(trainer: trainers[index]),
                    ),
              loading: () => const AppLoading(),
              error: (e, _) => AppError(message: e.toString()),
            ),
          ),
        ],
      ),
    );
  }
}

/// Back button + page title rendered at the top of the Team page.
/// The back action uses `context.pop()` when the navigation stack has
/// a previous route (Web back button, Android system back, Windows
/// keyboard backspace all route through it). When there's nothing to
/// pop — e.g. the user opened the page via a deep link — it falls back
/// to the Settings page so the user is never stranded.
class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.theme});
  final ThemeData theme;

  void _onBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/settings');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            tooltip: 'Înapoi',
            onPressed: () => _onBack(context),
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          Text(
            'Echipa centrului',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
