import 'package:flutter/material.dart';

import '../../../../core/widgets/status_badge.dart';
import '../../domain/workshop_detail_row.dart';

class ChildAttendanceTile extends StatelessWidget {
  const ChildAttendanceTile({super.key, required this.row});

  final WorkshopDetailRow row;

  BadgeStatus? get _badgeStatus => switch (row.attendanceStatus) {
        'present' => BadgeStatus.present,
        'absent' => BadgeStatus.absent,
        'motivated' => BadgeStatus.motivated,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.person_outlined),
      title: Text(
        '${row.childFirstName ?? ''} ${row.childLastName ?? ''}'.trim(),
      ),
      subtitle: row.parentName != null ? Text(row.parentName!) : null,
      trailing: _badgeStatus != null
          ? StatusBadge(status: _badgeStatus!)
          : null,
    );
  }
}
