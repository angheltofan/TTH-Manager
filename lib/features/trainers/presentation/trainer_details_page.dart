import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/date_utils.dart';
import '../../../core/utils/permission_utils.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../children/domain/assigned_workshop.dart';
import '../providers/trainers_providers.dart';

class TrainerDetailsPage extends ConsumerWidget {
  const TrainerDetailsPage({super.key, required this.trainerId});

  final String trainerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trainerAsync = ref.watch(trainerDetailProvider(trainerId));
    final workshopsAsync = ref.watch(trainerWorkshopsProvider(trainerId));
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/trainers'),
        ),
        title: const Text('Detalii trainer'),
      ),
      body: trainerAsync.when(
        loading: () => const AppLoading(),
        error: (e, _) => Center(child: AppError(message: e.toString())),
        data: (trainer) {
          if (trainer == null) {
            return const Center(child: Text('Trainerul nu a fost găsit.'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              // ── Info card ─────────────────────────────────────────────
              Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trainer.fullName,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Rol: ${roleName(trainer.role)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.outline),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Workshops (one per series) ────────────────────────────
              workshopsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (workshops) =>
                    _TrainerWorkshopsCard(workshops: workshops),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Trainer workshop list (read-only) ─────────────────────────────────────────

class _TrainerWorkshopsCard extends StatelessWidget {
  const _TrainerWorkshopsCard({required this.workshops});
  final List<AssignedWorkshop> workshops;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (workshops.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ateliere conduse',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (int i = 0; i < workshops.length; i++) ...[
            if (i > 0) const Divider(height: 20),
            _WorkshopRow(workshop: workshops[i]),
          ],
        ],
      ),
    );
  }
}

class _WorkshopRow extends StatelessWidget {
  const _WorkshopRow({required this.workshop});
  final AssignedWorkshop workshop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time =
        '${formatTimeString(workshop.startTime)} – ${formatTimeString(workshop.endTime)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(workshop.title,
            style: theme.textTheme.bodyLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Wrap(spacing: 14, runSpacing: 4, children: [
          _Meta(Icons.calendar_today_outlined, workshop.dayOfWeek),
          _Meta(Icons.schedule_outlined, time),
        ]),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: theme.colorScheme.outline),
      const SizedBox(width: 4),
      Text(label,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline)),
    ]);
  }
}
