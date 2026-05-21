import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/permission_utils.dart';
import '../../../core/utils/weekday_utils.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../workshops/domain/workshop_series.dart';
import '../providers/trainers_providers.dart';

class TrainerDetailsPage extends ConsumerWidget {
  const TrainerDetailsPage({super.key, required this.trainerId});

  final String trainerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trainerAsync = ref.watch(trainerDetailProvider(trainerId));
    final seriesAsync = ref.watch(trainerSeriesProvider(trainerId));
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
        title: trainerAsync.maybeWhen(
          data: (t) => Text(t?.fullName ?? 'Trainer'),
          orElse: () => const Text('Detalii trainer'),
        ),
      ),
      body: trainerAsync.when(
        loading: () => const AppLoading(),
        error: (e, _) => Center(child: AppError(message: e.toString())),
        data: (trainer) {
          if (trainer == null) {
            return const Center(
                child: Text('Trainerul nu a fost găsit.'));
          }

          final isAdmin = trainer.role == 'admin';
          final accent = isAdmin ? AppColors.purple : AppColors.info;
          final initials = [
            trainer.firstName.isNotEmpty ? trainer.firstName[0] : '',
            trainer.lastName.isNotEmpty ? trainer.lastName[0] : '',
          ].join().toUpperCase();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              // ── Profile card ──────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color:
                          theme.colorScheme.outline.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    // Initials avatar
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initials,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: accent,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trainer.fullName,
                            style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              roleName(trainer.role),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: accent,
                              ),
                            ),
                          ),
                          if (trainer.createdAt != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Înregistrat: ${formatDate(trainer.createdAt!)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.outline),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Series count badge
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${trainer.workshopsCount}',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.purple,
                          ),
                        ),
                        Text(
                          'serii active',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Workshop series card ───────────────────────────────
              seriesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (series) => _TrainerSeriesCard(series: series),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Workshop series list for the trainer ─────────────────────────────────────

class _TrainerSeriesCard extends StatelessWidget {
  const _TrainerSeriesCard({required this.series});
  final List<WorkshopSeries> series;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (series.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(Icons.event_available_outlined,
                color: theme.colorScheme.outline, size: 20),
            const SizedBox(width: 10),
            Text(
              'Nicio serie de atelier activă.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
      );
    }

    // Group series by day_of_week, preserving the Mon→Sun sort order.
    final Map<String, List<WorkshopSeries>> byDay = {};
    for (final s in series) {
      final day = s.dayOfWeek ?? 'Necunoscut';
      byDay.putIfAbsent(day, () => []).add(s);
    }

    // Sort day keys by weekday index (should already be sorted, but be safe).
    final sortedDays = byDay.keys.toList()
      ..sort((a, b) => weekdayIndex(a).compareTo(weekdayIndex(b)));

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
          Row(
            children: [
              Text(
                'Ateliere conduse',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${series.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.purple,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (int di = 0; di < sortedDays.length; di++) ...[
            if (di > 0) const SizedBox(height: 10),
            _DaySection(
              day: sortedDays[di],
              workshops: byDay[sortedDays[di]]!,
            ),
          ],
        ],
      ),
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({required this.day, required this.workshops});
  final String day;
  final List<WorkshopSeries> workshops;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.outline.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            day,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
              letterSpacing: 0.2,
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (int i = 0; i < workshops.length; i++) ...[
          if (i > 0)
            Divider(
                height: 14,
                indent: 8,
                color:
                    theme.colorScheme.outline.withValues(alpha: 0.12)),
          _SeriesRow(series: workshops[i]),
        ],
      ],
    );
  }
}

class _SeriesRow extends StatelessWidget {
  const _SeriesRow({required this.series});
  final WorkshopSeries series;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final endLabel =
        series.endTime != null ? formatTimeString(series.endTime!) : '';
    final timeLabel =
        '${formatTimeString(series.startTime)} – $endLabel'.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  series.title,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (series.workshopType != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    series.workshopType!,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline),
                  ),
                ],
              ],
            ),
          ),
          _TimePill(label: timeLabel),
        ],
      ),
    );
  }
}

class _TimePill extends StatelessWidget {
  const _TimePill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.purple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_outlined,
              size: 12, color: AppColors.purple),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.purple,
            ),
          ),
        ],
      ),
    );
  }
}

