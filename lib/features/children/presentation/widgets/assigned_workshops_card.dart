import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../afterschool/domain/afterschool_program.dart';
import '../../../afterschool/providers/afterschool_providers.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../workshops/domain/workshop_series.dart';
import '../../../workshops/providers/enrollment_providers.dart';
import 'add_to_workshop_dialog.dart';
import 'details_section_card.dart';

/// Lists every program the child participates in — workshops AND
/// Afterschool programs. Keeps the single card chrome from the
/// previous "Atelierul la care vine" (same icon + title style);
/// workshop rows retain their exact behaviour (unchanged), Afterschool
/// rows are rendered inline below so admins see both types in one
/// place.
class AssignedWorkshopsCard extends ConsumerWidget {
  const AssignedWorkshopsCard({super.key, required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seriesAsync = ref.watch(childWorkshopSeriesProvider(childId));
    final afsEnrollmentsAsync =
        ref.watch(afterschoolEnrollmentsForChildProvider(childId));
    final afsProgramsAsync = ref.watch(afterschoolAllProgramsProvider);
    final isAdmin =
        ref.watch(currentProfileProvider).valueOrNull?.isAdmin ?? false;
    final theme = Theme.of(context);

    final trailing = isAdmin
        ? TextButton.icon(
            onPressed: () => _openAddDialog(context, ref),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Adaugă atelier'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.purple,
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              textStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
            ),
          )
        : null;

    // Resolve the (program, enrollment) pairs the child is currently
    // ACTIVE in. We filter to active + enrolled_until-null so a child
    // whose Afterschool enrolment ended doesn't show as still
    // participating; historical months remain visible in the "Istoric
    // cicluri" tab.
    final allAfsPrograms = afsProgramsAsync.valueOrNull ?? const [];
    final programsById = {for (final p in allAfsPrograms) p.id: p};
    final activeAfsEnrollments =
        (afsEnrollmentsAsync.valueOrNull ?? const [])
            .where((e) => e.isActive && e.enrolledUntil == null)
            .toList();
    final afsPairs = <_AfterschoolPair>[
      for (final e in activeAfsEnrollments)
        if (programsById[e.programId] != null)
          _AfterschoolPair(
            program: programsById[e.programId]!,
            enrollmentId: e.id,
          ),
    ]..sort((a, b) => a.program.name.compareTo(b.program.name));

    return DetailsSectionCard(
      title: 'Programele la care participă',
      iconData: Icons.school_rounded,
      iconColor: const Color(0xFF8B5CF6),
      trailing: trailing,
      child: seriesAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Center(
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child:
                      CircularProgressIndicator(strokeWidth: 2))),
        ),
        error: (e, _) => AppError(message: e.toString()),
        data: (series) {
          if (series.isEmpty && afsPairs.isEmpty) {
            return Text(
              'Niciun program înregistrat.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            );
          }
          final rows = <Widget>[];
          for (var i = 0; i < series.length; i++) {
            if (i > 0) rows.add(const Divider(height: 20));
            rows.add(_SeriesRow(
              series: series[i],
              isAdmin: isAdmin,
              onRemove: () => _removeWorkshop(context, ref, series[i]),
            ));
          }
          for (var i = 0; i < afsPairs.length; i++) {
            if (rows.isNotEmpty) rows.add(const Divider(height: 20));
            rows.add(_AfterschoolRow(pair: afsPairs[i], isAdmin: isAdmin));
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: rows,
          );
        },
      ),
    );
  }

  Future<void> _openAddDialog(
      BuildContext context, WidgetRef ref) async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => AddToWorkshopDialog(childId: childId),
    );
    if (added == true) {
      // Realtime (rt:workshop_enrollments) already invalidates
      // childWorkshopSeriesProvider(childId) on the same row change.
    }
  }

  Future<void> _removeWorkshop(BuildContext context, WidgetRef ref,
      WorkshopSeries series) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimină atelierul'),
        content: Text('Elimini copilul din "${series.title}"?'),
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
          .removeChildFromWorkshopSeries(childId, series.id);
      // Realtime (rt:workshop_enrollments) already invalidates
      // childWorkshopSeriesProvider(childId) on the same row change.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Copilul a fost eliminat din "${series.title}".')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        final s = e.toString();
        final msg = (s.contains('42501') || s.contains('403') || s.contains('permission'))
            ? 'Permisiune insuficientă. Contactați administratorul.'
            : 'Eroare: $e';
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg)));
      }
    }
  }
}

// ── Row widget ────────────────────────────────────────────────────────────────

class _SeriesRow extends StatelessWidget {
  const _SeriesRow({
    required this.series,
    required this.isAdmin,
    required this.onRemove,
  });

  final WorkshopSeries series;
  final bool isAdmin;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final endLabel =
        series.endTime != null ? formatTimeString(series.endTime!) : '';
    final timeLabel =
        '${formatTimeString(series.startTime)} – $endLabel';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () =>
                    context.push('/workshop-series/${series.id}'),
                child: Text(
                  series.title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.purple,
                    decoration: TextDecoration.underline,
                    decorationColor:
                        AppColors.purple.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
            if (isAdmin)
              TextButton(
                onPressed: onRemove,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: const Text('Elimină'),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            if (series.dayOfWeek != null &&
                series.dayOfWeek!.isNotEmpty)
              _Meta(Icons.calendar_today_outlined, series.dayOfWeek!),
            _Meta(Icons.schedule_outlined, timeLabel),
            if (series.trainerName != null &&
                series.trainerName!.isNotEmpty)
              _Meta(Icons.person_outline_rounded, series.trainerName!),
          ],
        ),
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

// ── Afterschool rows ─────────────────────────────────────────────────

class _AfterschoolPair {
  const _AfterschoolPair({
    required this.program,
    required this.enrollmentId,
  });
  final AfterschoolProgram program;
  final String enrollmentId;
}

class _AfterschoolRow extends StatelessWidget {
  const _AfterschoolRow({required this.pair, required this.isAdmin});
  final _AfterschoolPair pair;
  final bool isAdmin;

  static const _weekdaysShort = ['L', 'Ma', 'Mi', 'J', 'V', 'S', 'D'];

  String _daysLabel(Set<int> days) {
    final sorted = days.toList()..sort();
    return sorted.map((d) => _weekdaysShort[d - 1]).join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = pair.program;
    final hours = '${p.startTimeShort} – ${p.endTimeShort}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () =>
                    context.push('/afterschool/programs/${p.id}'),
                child: RichText(
                  text: TextSpan(
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.purple,
                      decoration: TextDecoration.underline,
                      decorationColor:
                          AppColors.purple.withValues(alpha: 0.4),
                    ),
                    children: [
                      TextSpan(text: p.name),
                      const TextSpan(
                        text: '  Afterschool',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: AppColors.purple,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            _Meta(Icons.calendar_today_outlined, _daysLabel(p.daysOfWeek)),
            _Meta(Icons.schedule_outlined, hours),
          ],
        ),
      ],
    );
  }
}
