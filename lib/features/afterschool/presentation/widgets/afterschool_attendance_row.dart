import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/initials_avatar.dart';
// Reuse the workshop attendance primitives: they are already the
// canonical compact toggle + read-only chip used across the app. No
// refactor of the workshop widget is required.
import '../../../workshops/presentation/widgets/attendance_mark_row.dart'
    show AttendanceToggleButton, AttendanceStatusChip;
import '../../domain/afterschool_attendance.dart';

/// Compact list row on the Afterschool session-day page.
///
/// Modelled on `ChildAttendanceRow` from the workshop details page:
///   • circular initials avatar via [ChildAvatar];
///   • name (bodyMedium/600) + optional "Sosire estimată" secondary line;
///   • pair of [AttendanceToggleButton]s on the right (Prezent/Absent)
///     with the same size/spacing as the workshop attendance list;
///   • small × icon for un-mark, discreetly at the end of the row.
///
/// Mobile / desktop layouts follow the same responsive split the
/// workshop row uses via `context.isMobile`.
class AfterschoolAttendanceRow extends StatelessWidget {
  const AfterschoolAttendanceRow({
    super.key,
    required this.childName,
    this.expectedArrivalTime,
    this.attendance,
    required this.onMark,
    required this.onUnmark,
    this.locked = false,
    this.unexpected = false,
  });

  final String childName;
  final String? expectedArrivalTime;
  final AfterschoolAttendance? attendance;
  final ValueChanged<AttendanceStatus> onMark;
  final VoidCallback onUnmark;
  final bool locked;

  /// When true, the row is displayed inside the secondary "În afara
  /// programului" section — carries a small warning-tinted chip below
  /// the name.
  final bool unexpected;

  String? get _statusDb => attendance?.status.toDb();
  bool get _isMarked => attendance != null;

  String? get _arrivalShort {
    final t = expectedArrivalTime;
    if (t == null || t.isEmpty) return null;
    return t.length >= 5 ? t.substring(0, 5) : t;
  }

  @override
  Widget build(BuildContext context) {
    return context.isMobile ? _mobile(context) : _desktop(context);
  }

  Widget _desktop(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          ChildAvatar(name: childName, size: 40),
          const SizedBox(width: 12),
          Expanded(child: _nameBlock(theme)),
          const SizedBox(width: 12),
          _controls(context),
        ],
      ),
    );
  }

  Widget _mobile(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ChildAvatar(name: childName, size: 36),
              const SizedBox(width: 10),
              Expanded(child: _nameBlock(theme)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 46),
            child: _controls(context),
          ),
        ],
      ),
    );
  }

  Widget _nameBlock(ThemeData theme) {
    final arrival = _arrivalShort;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          childName,
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (arrival != null)
          Text(
            'Sosire estimată: $arrival',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        if (unexpected)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _unexpectedPill(theme),
          ),
      ],
    );
  }

  Widget _controls(BuildContext context) {
    if (locked) {
      // Closed session — read-only display in the shared chip style.
      return AttendanceStatusChip(status: _statusDb);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AttendanceToggleButton(
          label: 'Prezent',
          icon: Icons.check_rounded,
          selected: _statusDb == 'present',
          selectedColor: AppColors.success,
          onTap: () => onMark(AttendanceStatus.present),
        ),
        const SizedBox(width: 8),
        AttendanceToggleButton(
          label: 'Absent',
          icon: Icons.close_rounded,
          selected: _statusDb == 'absent',
          selectedColor: AppColors.error,
          onTap: () => onMark(AttendanceStatus.absent),
        ),
        if (_isMarked) ...[
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Anulează marcarea',
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.close, size: 16),
            onPressed: onUnmark,
          ),
        ],
      ],
    );
  }

  Widget _unexpectedPill(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
      ),
      child: const Text(
        'În afara programului',
        style: TextStyle(
          color: AppColors.warning,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
