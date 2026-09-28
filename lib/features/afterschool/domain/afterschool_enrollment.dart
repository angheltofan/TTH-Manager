/// One enrollment row from `afterschool_enrollments`. History is
/// preserved by keeping past rows and setting `enrolledUntil` when a
/// child leaves — deliberately different from the workshop_enrollments
/// shape (which only tracks `is_active`) so we can reconstruct exactly
/// when a child was enrolled for any given date.
class AfterschoolEnrollment {
  const AfterschoolEnrollment({
    required this.id,
    required this.childId,
    required this.programId,
    required this.enrolledFrom,
    this.enrolledUntil,
    this.customMonthlyFee,
    this.attendanceDays,
    this.expectedArrivalTime,
    required this.isActive,
    this.notes,
    this.enrolledBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String childId;
  final String programId;
  final DateTime enrolledFrom;
  final DateTime? enrolledUntil;

  /// Override for the program's default fee. `null` = inherit.
  final double? customMonthlyFee;

  /// Per-child schedule inside the program's week. ISO weekday numbers
  /// (1 = Monday .. 7 = Sunday). `null` means "follows every program
  /// day". When set, it is a subset of the parent program's
  /// `daysOfWeek` — enforced by a DB trigger, so a value read from the
  /// server is trusted.
  final Set<int>? attendanceDays;

  /// Informational: the time the child normally arrives (e.g. after
  /// school). `HH:mm:ss` matching the program's time fields. Does NOT
  /// change attendance semantics — status stays present/absent/unmarked.
  final String? expectedArrivalTime;

  /// Admin toggle. Treat "currently enrolled" as
  /// `isActive && coversDate(today)`.
  final bool isActive;

  final String? notes;
  final String? enrolledBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// True when this enrollment covers `date` at least at the boundary.
  bool coversDate(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    if (d.isBefore(enrolledFrom)) return false;
    final until = enrolledUntil;
    if (until != null && d.isAfter(until)) return false;
    return true;
  }

  /// True when this enrollment overlaps ANY day in the given month.
  /// Used by the payment layer to decide whether a month is billable.
  bool coversMonth(int year, int month) {
    final monthStart = DateTime(year, month, 1);
    final monthEnd = DateTime(year, month + 1, 0);
    if (enrolledFrom.isAfter(monthEnd)) return false;
    final until = enrolledUntil;
    if (until != null && until.isBefore(monthStart)) return false;
    return true;
  }

  /// True when the child is expected on the given ISO weekday
  /// (1 = Monday .. 7 = Sunday). `attendanceDays == null` means "every
  /// program day" and returns true unconditionally.
  bool followsWeekday(int isoWeekday) {
    final days = attendanceDays;
    if (days == null) return true;
    return days.contains(isoWeekday);
  }

  /// Composite eligibility check used by the "who to expect today"
  /// view: enrollment covers the date AND the child follows that
  /// weekday. Session open/closed state is checked separately at the
  /// session level.
  bool isExpectedForDate(DateTime date) {
    if (!coversDate(date)) return false;
    return followsWeekday(date.weekday);
  }

  /// Currently-enrolled shortcut: active flag on + today falls inside
  /// [enrolledFrom, enrolledUntil].
  bool get isCurrentlyEnrolled =>
      isActive && coversDate(DateTime.now());

  factory AfterschoolEnrollment.fromMap(Map<String, dynamic> map) {
    Set<int>? days;
    final rawDays = map['attendance_days'];
    if (rawDays is List) {
      days = <int>{};
      for (final v in rawDays) {
        if (v is int) days.add(v);
        if (v is num) days.add(v.toInt());
      }
      if (days.isEmpty) days = null;
    }
    return AfterschoolEnrollment(
      id: map['id'] as String,
      childId: map['child_id'] as String,
      programId: map['program_id'] as String,
      enrolledFrom: DateTime.parse(map['enrolled_from'] as String),
      enrolledUntil: map['enrolled_until'] != null
          ? DateTime.parse(map['enrolled_until'] as String)
          : null,
      customMonthlyFee: map['custom_monthly_fee'] != null
          ? (map['custom_monthly_fee'] as num).toDouble()
          : null,
      attendanceDays: days,
      expectedArrivalTime: map['expected_arrival_time'] as String?,
      isActive: (map['is_active'] as bool?) ?? true,
      notes: map['notes'] as String?,
      enrolledBy: map['enrolled_by'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
