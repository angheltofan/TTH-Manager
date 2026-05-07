import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      body: trainersAsync.when(
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
    );
  }
}
