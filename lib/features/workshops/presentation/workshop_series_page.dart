import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/enrollment_providers.dart';
import 'widgets/enroll_children_dialog.dart';

class WorkshopSeriesPage extends ConsumerWidget {
  const WorkshopSeriesPage({super.key, required this.seriesId});

  final String seriesId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seriesAsync = ref.watch(workshopSeriesByIdProvider(seriesId));
    final childrenAsync =
        ref.watch(seriesEnrolledChildrenProvider(seriesId));
    final isAdmin =
        ref.watch(currentProfileProvider).valueOrNull?.isAdmin ?? false;
    final theme = Theme.of(context);

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
        title: const Text('Serie atelier'),
      ),
      body: seriesAsync.when(
        loading: () => const AppLoading(),
        error: (e, _) => Center(child: AppError(message: e.toString())),
        data: (series) {
          if (series == null) {
            return const Center(
                child: Text('Seria nu a fost găsită.'));
          }

          final endLabel = series.endTime != null
              ? formatTimeString(series.endTime!)
              : '';
          final timeLabel =
              '${formatTimeString(series.startTime)} – $endLabel';

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Info card ─────────────────────────────────────────
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
                          series.title,
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        if (series.workshopType != null)
                          _InfoRow(
                              icon: Icons.category_outlined,
                              label: series.workshopType!),
                        if (series.dayOfWeek != null &&
                            series.dayOfWeek!.isNotEmpty)
                          _InfoRow(
                              icon: Icons.calendar_today_outlined,
                              label: series.dayOfWeek!),
                        _InfoRow(
                            icon: Icons.schedule_outlined,
                            label: timeLabel),
                        if (series.trainerName != null &&
                            series.trainerName!.isNotEmpty)
                          _InfoRow(
                              icon: Icons.person_outline_rounded,
                              label: series.trainerName!),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Enrolled children ─────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: theme.colorScheme.outline
                            .withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(20, 18, 20, 14),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.purple
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.people_outline,
                                  size: 16, color: AppColors.purple),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Copii înscriși',
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(
                                      fontWeight: FontWeight.w700),
                            ),
                            const Spacer(),
                            if (isAdmin)
                              FilledButton.icon(
                                onPressed: () =>
                                    _openEnrollDialog(context, ref),
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Adaugă copii'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.purple,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  textStyle:
                                      const TextStyle(fontSize: 13),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Divider(
                          height: 1,
                          color: theme.colorScheme.outline
                              .withValues(alpha: 0.2)),
                      childrenAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                              child: CircularProgressIndicator(
                                  strokeWidth: 2)),
                        ),
                        error: (e, _) => Padding(
                          padding: const EdgeInsets.all(16),
                          child: AppError(message: e.toString()),
                        ),
                        data: (children) => children.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(24),
                                child: Center(
                                  child: Text(
                                    'Niciun copil înscris.',
                                    style:
                                        theme.textTheme.bodySmall
                                            ?.copyWith(
                                                color: theme
                                                    .colorScheme
                                                    .outline),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                physics:
                                    const NeverScrollableScrollPhysics(),
                                itemCount: children.length,
                                separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  indent: 20,
                                  color: theme.colorScheme.outline
                                      .withValues(alpha: 0.15),
                                ),
                                itemBuilder: (_, i) {
                                  final child = children[i];
                                  return ListTile(
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 4),
                                    title: Text(
                                      child.fullName,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                              fontWeight:
                                                  FontWeight.w600),
                                    ),
                                    onTap: () => context.push(
                                        '/children/${child.childId}'),
                                    trailing: isAdmin
                                        ? TextButton(
                                            onPressed: () =>
                                                _removeChild(
                                                    context,
                                                    ref,
                                                    child.childId),
                                            style:
                                                TextButton.styleFrom(
                                                    foregroundColor:
                                                        AppColors
                                                            .error),
                                            child:
                                                const Text('Elimină'),
                                          )
                                        : null,
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openEnrollDialog(
      BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (_) => EnrollChildrenDialog(seriesId: seriesId),
    );
    ref.invalidate(seriesEnrolledChildrenProvider(seriesId));
    ref.invalidate(availableChildrenForSeriesProvider(seriesId));
  }

  Future<void> _removeChild(
      BuildContext context, WidgetRef ref, String childId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimină copilul'),
        content: const Text(
            'Ești sigur că vrei să elimini acest copil din serie?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Anulează')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimină'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref
          .read(enrollmentRepositoryProvider)
          .removeChildFromWorkshopSeries(childId, seriesId);
      ref.invalidate(seriesEnrolledChildrenProvider(seriesId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Copilul a fost eliminat din serie.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare: $e')),
        );
      }
    }
  }
}

// ── Private widgets ───────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.outline),
          const SizedBox(width: 8),
          Text(label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.outline)),
        ],
      ),
    );
  }
}
