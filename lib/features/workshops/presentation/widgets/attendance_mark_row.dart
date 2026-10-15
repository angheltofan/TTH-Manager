import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/responsive.dart';
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
    if (context.isMobile) return _MobileRow(row: this);
    return _DesktopRow(row: this);
  }
}

// ── Mobile layout: name first, buttons below ─────────────────────────────────

class _MobileRow extends StatelessWidget {
  const _MobileRow({required this.row});
  final ChildAttendanceRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = row.row;
    final fullName =
        '${r.childFirstName ?? ''} ${r.childLastName ?? ''}'.trim();
    final status = r.attendanceStatus;

    return InkWell(
      onTap: row.onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row 1: avatar + name + parent ───────────────────────────
            Row(
              children: [
                ChildAvatar(
                  name: fullName,
                  size: 36,
                  workshopType: r.workshopType,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              fullName,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (r.isVisitor) ...[
                            const SizedBox(width: 6),
                            const _VisitorBadge(),
                          ],
                        ],
                      ),
                      if (_visitorSubtitle(r) != null)
                        Text(
                          _visitorSubtitle(r)!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.info,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      else if (r.parentName != null)
                        Text(
                          r.parentName!,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.outline),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            // ── Row 2: buttons or status chip ────────────────────────────
            if (row.isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 8, left: 46),
                child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (row.canMark)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 46),
                child: Row(
                  children: [
                    AttendanceToggleButton(
                      label: 'P',
                      icon: Icons.check_rounded,
                      selected: status == 'present',
                      selectedColor: AppColors.success,
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (_) => AttendanceDialog(
                          initialStatus: 'present',
                          currentObs: r.attendanceObservation,
                          onSave: row.onMark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AttendanceToggleButton(
                      label: 'A',
                      icon: Icons.close_rounded,
                      selected: status == 'absent',
                      selectedColor: AppColors.error,
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (_) => AttendanceDialog(
                          initialStatus: 'absent',
                          currentObs: r.attendanceObservation,
                          onSave: row.onMark,
                        ),
                      ),
                    ),
                    if (r.attendanceObservation != null &&
                        r.attendanceObservation!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          r.attendanceObservation!,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                              fontStyle: FontStyle.italic),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 46),
                child: AttendanceStatusChip(status: status),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Desktop layout: single row (unchanged behaviour) ─────────────────────────

class _DesktopRow extends StatelessWidget {
  const _DesktopRow({required this.row});
  final ChildAttendanceRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = row.row;
    final fullName =
        '${r.childFirstName ?? ''} ${r.childLastName ?? ''}'.trim();
    final status = r.attendanceStatus;

    return InkWell(
      onTap: row.onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            ChildAvatar(
              name: fullName,
              size: 40,
              workshopType: r.workshopType,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          fullName,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (r.isVisitor) ...[
                        const SizedBox(width: 6),
                        const _VisitorBadge(),
                      ],
                    ],
                  ),
                  if (_visitorSubtitle(r) != null)
                    Text(
                      _visitorSubtitle(r)!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.info,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  else if (r.parentName != null)
                    Text(
                      r.parentName!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (r.attendanceObservation != null &&
                      r.attendanceObservation!.isNotEmpty)
                    Text(
                      r.attendanceObservation!,
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
            if (row.isLoading)
              const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 2))
            else if (row.canMark)
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
                        currentObs: r.attendanceObservation,
                        onSave: row.onMark,
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
                        currentObs: r.attendanceObservation,
                        onSave: row.onMark,
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

/// Compact badge for a visitor attendance ("Prezență în altă grupă").
/// Rendered inline on the child name line. Keeps the row visually
/// lightweight — no extra line pair beyond the regular-group subtitle.
class _VisitorBadge extends StatelessWidget {
  const _VisitorBadge();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: const Text(
        'Altă grupă',
        style: TextStyle(
          color: AppColors.info,
          fontWeight: FontWeight.w800,
          fontSize: 9,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Builds the "Altă grupă · Marți 16:00" subtitle text for a visitor
/// row. Returns null if the row carries no visitor metadata.
String? _visitorSubtitle(WorkshopDetailRow r) {
  if (!r.isVisitor) return null;
  final day = r.visitorRegularDayOfWeek;
  final start = r.visitorRegularStartTime;
  if (day == null || start == null) return null;
  return 'Altă grupă · ${_dayLabel(day)} $start';
}

String _dayLabel(String code) {
  switch (code) {
    case 'LUNI':
      return 'Luni';
    case 'MARTI':
      return 'Marți';
    case 'MIERCURI':
      return 'Miercuri';
    case 'JOI':
      return 'Joi';
    case 'VINERI':
      return 'Vineri';
    case 'SAMBATA':
      return 'Sâmbătă';
    case 'DUMINICA':
      return 'Duminică';
    default:
      return code;
  }
}
