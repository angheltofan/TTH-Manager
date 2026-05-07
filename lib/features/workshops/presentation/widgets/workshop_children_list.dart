import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/workshop_detail_row.dart';
import '../../providers/enrollment_providers.dart';
import 'attendance_mark_row.dart';
import 'enroll_children_dialog.dart';

class WorkshopChildrenList extends StatelessWidget {
  const WorkshopChildrenList({
    super.key,
    required this.workshopId,
    required this.enrolled,
    required this.marking,
    required this.canMark,
    required this.onMark,
    this.onChildTap,
    this.isAdmin = false,
    this.seriesId,
    this.onEnrolled,
  });

  final String workshopId;
  final List<WorkshopDetailRow> enrolled;
  final Set<String> marking;
  final bool canMark;
  final Future<void> Function(String childId, String status, String? observation)
      onMark;
  final void Function(String childId)? onChildTap;
  final bool isAdmin;
  /// The recurring series id – when set and [isAdmin] is true, shows
  /// an "Adaugă copii" button that opens [EnrollChildrenDialog].
  final String? seriesId;
  final VoidCallback? onEnrolled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.people_outline,
                      size: 16, color: AppColors.purple),
                ),
                const SizedBox(width: 10),
                Text(
                  'Copii înscriși',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${enrolled.length}',
                    style: const TextStyle(
                      color: AppColors.purple,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (isAdmin && seriesId != null) ...[
                  _AddChildrenButton(
                    seriesId: seriesId!,
                    onEnrolled: onEnrolled,
                  ),
                ],
              ],
            ),
          ),
          Divider(
              height: 1,
              color: theme.colorScheme.outline.withValues(alpha: 0.2)),
          if (enrolled.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Niciun copil înscris în acest atelier.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: enrolled.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: theme.colorScheme.outline.withValues(alpha: 0.12),
              ),
              itemBuilder: (context, i) {
                final row = enrolled[i];
                final childId = row.childId!;
                return ChildAttendanceRow(
                  row: row,
                  isLoading: marking.contains(childId),
                  canMark: canMark,
                  onMark: (status, obs) => onMark(childId, status, obs),
                  onTap: onChildTap != null
                      ? () => onChildTap!(childId)
                      : null,
                );
              },
            ),
          if (enrolled.isNotEmpty) ...[
            Divider(
                height: 1,
                color:
                    theme.colorScheme.outline.withValues(alpha: 0.2)),
            _AttendanceSummaryRow(enrolled: enrolled),
          ],
        ],
      ),
    );
  }
}

class _AttendanceSummaryRow extends StatelessWidget {
  const _AttendanceSummaryRow({required this.enrolled});
  final List<WorkshopDetailRow> enrolled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = enrolled.length;
    final present =
        enrolled.where((r) => r.attendanceStatus == 'present').length;
    final absent =
        enrolled.where((r) => r.attendanceStatus == 'absent').length;
    final unmarked = total - present - absent;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        children: [
          _SummaryPill(
              label: 'Prezenți',
              count: present,
              color: AppColors.success),
          const SizedBox(width: 8),
          _SummaryPill(
              label: 'Absenți', count: absent, color: AppColors.error),
          const SizedBox(width: 8),
          _SummaryPill(
              label: 'Nemarcați',
              count: unmarked,
              color: theme.colorScheme.outline),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill(
      {required this.label, required this.count, required this.color});
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count $label',
        style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Adaugă copii button ────────────────────────────────────────────────────────

class _AddChildrenButton extends ConsumerWidget {
  const _AddChildrenButton({
    required this.seriesId,
    this.onEnrolled,
  });

  final String seriesId;
  final VoidCallback? onEnrolled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: TextButton.icon(
        onPressed: () => _open(context, ref),
        icon: const Icon(Icons.person_add_alt_1_outlined, size: 15),
        label: const Text('Adaugă copii'),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.purple,
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          textStyle: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final enrolled = await showDialog<bool>(
      context: context,
      builder: (_) => EnrollChildrenDialog(seriesId: seriesId),
    );
    if (enrolled == true) {
      ref.invalidate(availableChildrenForSeriesProvider(seriesId));
      ref.invalidate(seriesEnrolledChildrenProvider(seriesId));
      onEnrolled?.call();
    }
  }
}
