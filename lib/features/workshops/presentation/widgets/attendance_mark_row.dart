import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/initials_avatar.dart';
import '../../domain/workshop_detail_row.dart';
import 'attendance_dialog.dart';

class ChildAttendanceRow extends StatelessWidget {
  const ChildAttendanceRow({
    super.key,
    required this.row,
    required this.isLoading,
    required this.canMark,
    required this.onMark,
    this.onTap,
  });

  final WorkshopDetailRow row;
  final bool isLoading;
  final bool canMark;
  final void Function(String status, String? observation) onMark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fullName =
        '${row.childFirstName ?? ''} ${row.childLastName ?? ''}'.trim();
    final status = row.attendanceStatus;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            ChildAvatar(name: fullName, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fullName,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (row.parentName != null)
                    Text(
                      row.parentName!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (row.attendanceObservation != null &&
                      row.attendanceObservation!.isNotEmpty)
                    Text(
                      row.attendanceObservation!,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                          fontStyle: FontStyle.italic),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (isLoading)
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (canMark)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AttendanceToggleButton(
                    label: 'Prezent',
                    icon: Icons.check_rounded,
                    selected: status == 'present',
                    selectedColor: AppColors.success,
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (_) => AttendanceDialog(
                        initialStatus: 'present',
                        currentObs: row.attendanceObservation,
                        onSave: onMark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AttendanceToggleButton(
                    label: 'Absent',
                    icon: Icons.close_rounded,
                    selected: status == 'absent',
                    selectedColor: AppColors.error,
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (_) => AttendanceDialog(
                        initialStatus: 'absent',
                        currentObs: row.attendanceObservation,
                        onSave: onMark,
                      ),
                    ),
                  ),
                ],
              )
            else
              AttendanceStatusChip(status: status),
          ],
        ),
      ),
    );
  }
}

class AttendanceToggleButton extends StatelessWidget {
  const AttendanceToggleButton({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (selected) {
      return FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 14),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: selectedColor,
          foregroundColor: Colors.white,
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: theme.colorScheme.outline,
        side: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.4)),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class AttendanceStatusChip extends StatelessWidget {
  const AttendanceStatusChip({super.key, this.status});
  final String? status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'present' => ('Prezent', AppColors.success),
      'absent' => ('Absent', AppColors.error),
      _ => ('—', Theme.of(context).colorScheme.outline),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
