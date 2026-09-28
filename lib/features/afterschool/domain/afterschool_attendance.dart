/// One attendance row from `afterschool_attendance`.
///
/// UNMARKED is expressed by the absence of a row — there is no
/// `'unmarked'` status. `status` is strictly `present` or `absent`.
class AfterschoolAttendance {
  const AfterschoolAttendance({
    required this.id,
    required this.sessionId,
    required this.childId,
    required this.status,
    this.observation,
    required this.markedAt,
    this.markedBy,
    required this.updatedAt,
  });

  final String id;
  final String sessionId;
  final String childId;
  final AttendanceStatus status;
  final String? observation;
  final DateTime markedAt;
  final String? markedBy;
  final DateTime updatedAt;

  bool get isPresent => status == AttendanceStatus.present;
  bool get isAbsent => status == AttendanceStatus.absent;

  factory AfterschoolAttendance.fromMap(Map<String, dynamic> map) {
    return AfterschoolAttendance(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      childId: map['child_id'] as String,
      status: AttendanceStatus.fromDb(map['status'] as String? ?? 'absent'),
      observation: map['observation'] as String?,
      markedAt: DateTime.parse(map['marked_at'] as String),
      markedBy: map['marked_by'] as String?,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

enum AttendanceStatus {
  present,
  absent;

  String toDb() => name;

  static AttendanceStatus fromDb(String raw) {
    switch (raw) {
      case 'present':
        return AttendanceStatus.present;
      case 'absent':
      default:
        return AttendanceStatus.absent;
    }
  }
}
