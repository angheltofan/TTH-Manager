import 'package:flutter/material.dart';

import '../../../../core/widgets/section_card.dart';
import '../../../children/presentation/widgets/attendance_row_item.dart';
import '../../domain/parent_dashboard.dart';

/// "Activitate recentă" section on the parent dashboard. Re-uses the
/// same `SectionCard` shell + the staff [AttendanceRowItem] used on
/// the Child Details page so the row look (index circle, info lines,
/// status badge, mobile/desktop layouts) is identical across roles.
///
/// For multi-child parents we prepend the child's name to the
/// "Atelier" line so each row is unambiguous; with one child the row
/// stays compact.
class ParentRecentActivityCard extends StatelessWidget {
  const ParentRecentActivityCard({
    super.key,
    required this.items,
    required this.showChildName,
  });

  final List<ParentRecentActivityItem> items;

  /// When the parent has >1 child, prefix the workshop title in each
  /// row with the child's full name. With 1 child the prefix is
  /// redundant.
  final bool showChildName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (items.isEmpty) {
      return SectionCard(
        title: 'Activitate recentă',
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_rounded,
                    color: theme.colorScheme.outline, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Nu există activitate recentă.',
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
      title: 'Activitate recentă',
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          // No table header here — the dashboard feed is a chronological
          // list, not an indexed cycle table. The row widget renders
          // identically without it.
          for (var i = 0; i < items.length; i++)
            AttendanceRowItem(
              index: i + 1,
              workshopTitle: _composeWorkshopTitle(items[i]),
              dayOfWeek: items[i].dayOfWeek,
              workshopDate: items[i].workshopDate,
              startTime: items[i].startTime,
              endTime: items[i].endTime,
              attendanceStatus: items[i].status,
              observation: items[i].observation,
            ),
        ],
      ),
    );
  }

  String _composeWorkshopTitle(ParentRecentActivityItem item) {
    final ws = item.workshopLabel;
    if (!showChildName) return ws;
    final name = item.childFullName;
    if (name.isEmpty) return ws;
    return '$name · $ws';
  }
}
