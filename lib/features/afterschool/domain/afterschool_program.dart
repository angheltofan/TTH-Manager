/// Configuration of one Afterschool program. Rows come from the
/// `afterschool_programs` table. Multiple programs may coexist.
///
/// Archiving semantics match `workshop_series`: `archived_at != null`
/// together with `is_active = false` marks a retired program. Sessions
/// already generated survive for history.
class AfterschoolProgram {
  const AfterschoolProgram({
    required this.id,
    required this.name,
    this.description,
    required this.daysOfWeek,
    required this.startTime,
    required this.endTime,
    required this.monthlyFee,
    required this.currency,
    this.maxCapacity,
    required this.activeFrom,
    this.activeTo,
    required this.isActive,
    this.archivedAt,
    this.archivedBy,
    this.archivedReason,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? description;

  /// ISO weekday numbers (1 = Monday .. 7 = Sunday). E.g. `{1,2,3,4,5}`
  /// for a Monday-to-Friday program.
  final Set<int> daysOfWeek;

  /// `HH:mm:ss` as returned by Postgres `time`.
  final String startTime;
  final String endTime;

  final double monthlyFee;
  final String currency;

  /// Optional hard cap on the number of active enrolled children. `null`
  /// = no cap. Not enforced by the DB in Phase 1 — the UI computes
  /// `active / maxCapacity` and warns when the cap is reached.
  final int? maxCapacity;

  final DateTime activeFrom;
  final DateTime? activeTo;

  final bool isActive;
  final DateTime? archivedAt;
  final String? archivedBy;
  final String? archivedReason;

  final String? notes;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// True when the program is retired. Any of `!isActive` or
  /// `archivedAt != null` is enough — we tolerate historic drift
  /// between the two flags (learned from workshop_series legacy).
  bool get isArchived => !isActive || archivedAt != null;

  /// Deterministic check "does this date fall inside a program day
  /// that is within the program's active window". Used by the client
  /// before rendering a calendar cell so the UI never asks for
  /// attendance on a day that could not have a session.
  bool isEligibleDay(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    if (day.isBefore(activeFrom)) return false;
    final to = activeTo;
    if (to != null && day.isAfter(to)) return false;
    return daysOfWeek.contains(day.weekday);
  }

  /// Convenience — `HH:mm`.
  String get startTimeShort =>
      startTime.length >= 5 ? startTime.substring(0, 5) : startTime;
  String get endTimeShort =>
      endTime.length >= 5 ? endTime.substring(0, 5) : endTime;

  factory AfterschoolProgram.fromMap(Map<String, dynamic> map) {
    final rawDays = map['days_of_week'];
    final days = <int>{};
    if (rawDays is List) {
      for (final v in rawDays) {
        if (v is int) days.add(v);
        if (v is num) days.add(v.toInt());
      }
    }
    return AfterschoolProgram(
      id: map['id'] as String,
      name: (map['name'] as String?) ?? '',
      description: map['description'] as String?,
      daysOfWeek: days,
      startTime: (map['start_time'] as String?) ?? '',
      endTime: (map['end_time'] as String?) ?? '',
      monthlyFee: (map['monthly_fee'] as num).toDouble(),
      currency: (map['currency'] as String?) ?? 'RON',
      maxCapacity: map['max_capacity'] != null
          ? (map['max_capacity'] as num).toInt()
          : null,
      activeFrom: DateTime.parse(map['active_from'] as String),
      activeTo: map['active_to'] != null
          ? DateTime.parse(map['active_to'] as String)
          : null,
      isActive: (map['is_active'] as bool?) ?? true,
      archivedAt: map['archived_at'] != null
          ? DateTime.parse(map['archived_at'] as String)
          : null,
      archivedBy: map['archived_by'] as String?,
      archivedReason: map['archived_reason'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
