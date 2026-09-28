/// One row from `afterschool_sessions` — a concrete program-day.
///
/// [variant] is intentionally exposed as a plain string so future
/// values (like `'special'` for a modified schedule) can flow through
/// without a schema-driven enum update on every domain add. UI code
/// switches on `variant` explicitly.
///
/// CLOSED is a first-class concept: `isClosed = true` means "this day
/// does not run" (holiday, center closed, event cancelled). It is
/// deliberately NOT the same as UNMARKED attendance. Callers should
/// use [isEligibleForAttendance] to gate the mark-present UI.
class AfterschoolSession {
  const AfterschoolSession({
    required this.id,
    required this.programId,
    required this.sessionDate,
    required this.startTime,
    required this.endTime,
    this.variant = SessionVariant.regular,
    this.isClosed = false,
    this.closedReason,
    this.closedBy,
    this.closedAt,
    required this.createdAt,
  });

  final String id;
  final String programId;
  final DateTime sessionDate;
  final String startTime;
  final String endTime;

  final SessionVariant variant;

  final bool isClosed;
  final String? closedReason;
  final String? closedBy;
  final DateTime? closedAt;

  final DateTime createdAt;

  /// Session may accept attendance today. False on CLOSED days.
  /// The UI additionally checks whether the child was enrolled on
  /// [sessionDate]; that lookup lives in the enrollment layer.
  bool get isEligibleForAttendance => !isClosed;

  String get startTimeShort =>
      startTime.length >= 5 ? startTime.substring(0, 5) : startTime;
  String get endTimeShort =>
      endTime.length >= 5 ? endTime.substring(0, 5) : endTime;

  factory AfterschoolSession.fromMap(Map<String, dynamic> map) {
    return AfterschoolSession(
      id: map['id'] as String,
      programId: map['program_id'] as String,
      sessionDate: DateTime.parse(map['session_date'] as String),
      startTime: (map['start_time'] as String?) ?? '',
      endTime: (map['end_time'] as String?) ?? '',
      variant: SessionVariant.fromDb(map['variant'] as String?),
      isClosed: (map['is_closed'] as bool?) ?? false,
      closedReason: map['closed_reason'] as String?,
      closedBy: map['closed_by'] as String?,
      closedAt: map['closed_at'] != null
          ? DateTime.parse(map['closed_at'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

/// Session type. Starts with `regular` and `special`; extend when the
/// business defines a new day type. New values must also be added to
/// the DB check constraint.
enum SessionVariant {
  regular,
  special;

  String toDb() => name;

  static SessionVariant fromDb(String? raw) {
    switch (raw) {
      case 'special':
        return SessionVariant.special;
      case 'regular':
      default:
        return SessionVariant.regular;
    }
  }
}
