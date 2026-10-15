/// A single attendance row in the child's current payment cycle.
/// Parsed from the `child_current_status_rows` view.
class ChildCurrentStatusRow {
  const ChildCurrentStatusRow({
    required this.childId,
    this.attendanceId,
    this.workshopTitle,
    this.workshopDate,
    this.dayOfWeek,
    this.startTime,
    this.endTime,
    this.attendanceStatus,
    this.observation,
    this.seriesId,
    this.seriesTitle,
    this.paymentCycleId,
    this.creditedSeriesId,
  });

  final String childId;
  final String? attendanceId;
  final String? workshopTitle;
  final DateTime? workshopDate;
  final String? dayOfWeek;
  final String? startTime;
  final String? endTime;

  /// 'present', 'absent', 'motivated', or null (unmarked).
  final String? attendanceStatus;
  final String? observation;

  /// The workshop series this row belongs to. Added 2026-08-20 for per-
  /// series grouping. Nullable for legacy rows fetched without the join.
  final String? seriesId;
  /// Human-readable series title (from workshop_series.title).
  final String? seriesTitle;

  /// Financial linkage to a payment cycle. Set for PRESENT rows that are
  /// part of a closed 4-session cycle. Always NULL for ABSENT rows —
  /// which is why absences must be classified by workshop_date, not by
  /// this field.
  final String? paymentCycleId;

  /// Visitor override — when non-null, the attendance credits this
  /// series' cycle instead of the physical [seriesId]. Snapshot grouping
  /// must prefer this over [seriesId] (see `series_snapshot.dart`).
  final String? creditedSeriesId;

  /// Returns the series that should OWN this row in the Child Details
  /// financial timeline: the credit override if set, otherwise the
  /// physical series.
  String? get billingSeriesId => creditedSeriesId ?? seriesId;

  factory ChildCurrentStatusRow.fromMap(Map<String, dynamic> map) =>
      ChildCurrentStatusRow(
        childId: (map['child_id'] as String?) ?? '',
        attendanceId: map['attendance_id'] as String?,
        workshopTitle: map['workshop_title'] as String?,
        workshopDate: map['workshop_date'] != null
            ? DateTime.tryParse(map['workshop_date'] as String)
            : null,
        dayOfWeek: map['day_of_week'] as String?,
        startTime: map['start_time'] as String?,
        endTime: map['end_time'] as String?,
        attendanceStatus: map['attendance_status'] as String?,
        observation: map['observation'] as String?,
        creditedSeriesId: map['credited_series_id'] as String?,
      );
}
