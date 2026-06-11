import 'package:flutter/material.dart';

import '../../../../core/widgets/section_card.dart';
import '../../../dashboard/domain/dashboard_workshop.dart';
import '../../../dashboard/presentation/widgets/dashboard_workshop_item.dart';
import '../../domain/parent_dashboard.dart';

/// "Program săptămâna aceasta" section on the parent dashboard.
/// Re-uses the same `SectionCard` shell and the staff
/// [DashboardWorkshopItem] row used by the admin dashboard, so the
/// parent experience visually inherits the staff workshop list style.
///
/// `customChildrenLabel` is the only parent-specific seam — the staff
/// row by default shows "{n} copii" (total class size). For parents
/// we replace that meta with the parent's own children's first names
/// for the session, e.g. "Sofia, Matei". With only one child the
/// label is dropped so the row stays clean.
///
/// Rows are non-tappable for parents: omitting `onTap` keeps
/// [DashboardWorkshopItem] from navigating to the staff workshop
/// detail page (which the parent can't reach anyway).
class ParentWeeklyScheduleCard extends StatelessWidget {
  const ParentWeeklyScheduleCard({
    super.key,
    required this.sessions,
    required this.showChildNames,
  });

  final List<ParentWeeklySession> sessions;

  /// When the parent has >1 child, render the attending-children names
  /// in the row's meta. With 1 child the names are redundant noise.
  final bool showChildNames;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (sessions.isEmpty) {
      return SectionCard(
        title: 'Program săptămâna aceasta',
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_busy_outlined,
                    color: theme.colorScheme.outline, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Nu există ateliere programate.',
                  style: TextStyle(
                    color: theme.colorScheme.outline,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SectionCard(
      title: 'Program săptămâna aceasta',
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          for (final s in sessions)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DashboardWorkshopItem(
                workshop: _toDashboardWorkshop(s),
                showDate: true,
                customChildrenLabel:
                    showChildNames ? _joinNames(s.childFirstNames) : null,
              ),
            ),
        ],
      ),
    );
  }

  /// Adapts a `ParentWeeklySession` (RLS-scoped, possibly partial) into
  /// the staff `DashboardWorkshop` shape so we can reuse the staff row.
  /// Strings that are nullable on the parent model fall back to safe
  /// empty defaults — the visible field is the title; the rest comes
  /// from the row's meta line.
  static DashboardWorkshop _toDashboardWorkshop(ParentWeeklySession s) {
    return DashboardWorkshop(
      id: s.scheduledWorkshopId,
      title: s.displayLabel,
      workshopType: s.workshopType ?? '',
      workshopDate: s.workshopDate ?? DateTime.now(),
      dayOfWeek: s.dayOfWeek ?? '',
      startTime: s.startTime ?? '',
      endTime: s.endTime ?? '',
      trainerId: '',
      trainerName: s.trainerName,
      // Parent role doesn't read total class size; the customChildrenLabel
      // path supplies the parent's own children's names instead.
    );
  }

  static String? _joinNames(List<String> names) {
    final cleaned = names.where((n) => n.trim().isNotEmpty).toList();
    if (cleaned.isEmpty) return null;
    return cleaned.join(', ');
  }
}
