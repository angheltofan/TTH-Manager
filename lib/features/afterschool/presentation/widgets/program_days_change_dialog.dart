import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/afterschool_enrollment.dart';
import 'weekday_multi_selector.dart';

/// Result of the "program days changed" impact analysis for a set of
/// active enrollments (see [computeProgramDaysChangeImpact]).
class ProgramDaysChangeImpact {
  const ProgramDaysChangeImpact({
    required this.unaffected,
    required this.normalizable,
    required this.blockers,
  });

  /// Enrollments whose `attendance_days` is entirely inside the new
  /// program days (or is NULL). No client action needed.
  final List<AfterschoolEnrollment> unaffected;

  /// Enrollments whose `attendance_days` will be normalized to the
  /// intersection (non-empty and different from current). Each entry
  /// carries the new set the server will compute.
  final List<NormalizableEntry> normalizable;

  /// Enrollments whose intersection would be empty — the program save
  /// must be blocked and each blocker resolved by the admin first.
  final List<AfterschoolEnrollment> blockers;

  bool get anyChanges => normalizable.isNotEmpty || blockers.isNotEmpty;
}

class NormalizableEntry {
  const NormalizableEntry({
    required this.enrollment,
    required this.newAttendanceDays,
  });
  final AfterschoolEnrollment enrollment;
  final Set<int> newAttendanceDays;
}

/// Pure function: partition active enrollments against the new program
/// days_of_week. Mirrors the server's `update_afterschool_program` RPC
/// logic (see 20260930 migration). The server is still the source of
/// truth at commit time — this is preview only.
ProgramDaysChangeImpact computeProgramDaysChangeImpact({
  required List<AfterschoolEnrollment> activeEnrollments,
  required Set<int> newProgramDays,
}) {
  final unaffected = <AfterschoolEnrollment>[];
  final normalizable = <NormalizableEntry>[];
  final blockers = <AfterschoolEnrollment>[];

  for (final e in activeEnrollments) {
    final days = e.attendanceDays;
    if (days == null) {
      // NULL means "follows all program days" — meaning changes with
      // the program but stays valid.
      unaffected.add(e);
      continue;
    }
    final intersection = days.intersection(newProgramDays);
    if (intersection.isEmpty) {
      blockers.add(e);
    } else if (intersection.length == days.length &&
        intersection.containsAll(days)) {
      unaffected.add(e);
    } else {
      normalizable.add(NormalizableEntry(
          enrollment: e, newAttendanceDays: intersection));
    }
  }

  return ProgramDaysChangeImpact(
    unaffected: unaffected,
    normalizable: normalizable,
    blockers: blockers,
  );
}

/// Dialog shown when the admin narrows a program's `days_of_week` and
/// at least one active enrollment is affected.
///
/// UX contract from Phase 2 spec:
///   • blockers non-empty → save is disabled, admin must resolve first;
///   • otherwise show old→new for each `normalizable` entry and get
///     explicit admin confirmation.
///
/// Returns true when the admin confirms the change (implies zero
/// blockers). Returns false / null on cancel or block.
Future<bool?> showProgramDaysChangeDialog({
  required BuildContext context,
  required Map<String, String> childNamesById,
  required ProgramDaysChangeImpact impact,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => _ProgramDaysChangeDialog(
      childNamesById: childNamesById,
      impact: impact,
    ),
  );
}

class _ProgramDaysChangeDialog extends StatelessWidget {
  const _ProgramDaysChangeDialog({
    required this.childNamesById,
    required this.impact,
  });
  final Map<String, String> childNamesById;
  final ProgramDaysChangeImpact impact;

  String _name(String childId) => childNamesById[childId] ?? childId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasBlockers = impact.blockers.isNotEmpty;

    return AlertDialog(
      title: Text(hasBlockers
          ? 'Nu poți salva încă'
          : 'Modificarea afectează copii înscriși'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 460),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasBlockers)
                _blockersSection(theme),
              if (impact.normalizable.isNotEmpty) ...[
                if (hasBlockers) const SizedBox(height: 16),
                _normalizableSection(theme, blocked: hasBlockers),
              ],
              if (!hasBlockers &&
                  impact.normalizable.isEmpty) ...[
                Text(
                  'Nimic de ajustat pentru copiii înscriși.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(hasBlockers ? 'Închide' : 'Renunță'),
        ),
        if (!hasBlockers)
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.purple),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(impact.normalizable.isEmpty
                ? 'Continuă'
                : 'Confirmă și salvează'),
          ),
      ],
    );
  }

  Widget _blockersSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.block, color: AppColors.error, size: 18),
            const SizedBox(width: 8),
            Text(
              impact.blockers.length == 1
                  ? '1 copil ar rămâne fără nicio zi de participare'
                  : '${impact.blockers.length} copii ar rămâne fără nicio zi de participare',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.error,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          for (final e in impact.blockers)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                '• ${_name(e.childId)}: ${formatIsoWeekdaysShort(e.attendanceDays!)}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Actualizează programul individual al fiecărui copil sau '
            'încheie înscrierea, apoi revino aici.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }

  Widget _normalizableSection(ThemeData theme, {required bool blocked}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (blocked ? AppColors.muted : AppColors.info)
            .withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color:
                (blocked ? AppColors.muted : AppColors.info)
                    .withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.tune,
                color: blocked ? AppColors.muted : AppColors.info,
                size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                impact.normalizable.length == 1
                    ? '1 program individual va fi ajustat automat'
                    : '${impact.normalizable.length} programe individuale vor fi ajustate automat',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          for (final entry in impact.normalizable)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                '• ${_name(entry.enrollment.childId)}: '
                '${formatIsoWeekdaysShort(entry.enrollment.attendanceDays!)}'
                ' → ${formatIsoWeekdaysShort(entry.newAttendanceDays)}',
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}
