class WorkshopDetailRow {
  const WorkshopDetailRow({
    required this.workshopId,
    required this.title,
    required this.workshopType,
    required this.workshopDate,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.trainerId,
    this.seriesId,
    this.recurringSeriesId,
    this.trainerName,
    this.childId,
    this.childFirstName,
    this.childLastName,
    this.parentName,
    this.attendanceStatus,
    this.attendanceObservation,
    this.creditedSeriesId,
    this.visitorRegularDayOfWeek,
    this.visitorRegularStartTime,
    this.visitorRegularSeriesTitle,
  });

  final String workshopId;
  final String title;
  final String workshopType;
  final DateTime workshopDate;
  final String dayOfWeek;
  final String startTime;
  final String endTime;
  final String trainerId;

  /// Canonical FK to `workshop_series.id` (current column).
  final String? seriesId;

  /// Legacy column for series id used by older rows that haven't been
  /// backfilled. Code that decides "is this a recurring instance?"
  /// must check both.
  final String? recurringSeriesId;

  final String? trainerName;
  final String? childId;
  final String? childFirstName;
  final String? childLastName;
  final String? parentName;
  final String? attendanceStatus;
  final String? attendanceObservation;

  /// Non-null when this attendance row carries a billing-credit override
  /// (= "Prezență în altă grupă" / visitor). The physical scheduled
  /// workshop is this row's own [workshopId]; the credited series
  /// receives the four-session cycle credit instead.
  final String? creditedSeriesId;

  /// Visitor label fields — the regular group the child is enrolled in.
  final String? visitorRegularDayOfWeek;
  final String? visitorRegularStartTime;
  final String? visitorRegularSeriesTitle;

  /// A row that was NOT in the enrolled roster but has an attendance
  /// against this physical session with [creditedSeriesId] pointing at
  /// the child's actual enrollment. Rendered with the "Altă grupă" badge.
  bool get isVisitor => creditedSeriesId != null;

  /// True when this scheduled workshop was created from (or attached
  /// to) a recurring series. Used to gate the hard-delete action —
  /// recurring instances must only be cancelled.
  bool get isRecurringInstance =>
      (seriesId != null && seriesId!.isNotEmpty) ||
      (recurringSeriesId != null && recurringSeriesId!.isNotEmpty);

  factory WorkshopDetailRow.fromMap(Map<String, dynamic> map) {
    return WorkshopDetailRow(
      workshopId: map['workshop_id'] as String,
      title: map['title'] as String,
      workshopType: map['workshop_type'] as String,
      workshopDate: DateTime.parse(map['workshop_date'] as String),
      dayOfWeek: map['day_of_week'] as String,
      startTime: map['start_time'] as String,
      endTime: map['end_time'] as String,
      trainerId: map['trainer_id'] as String,
      seriesId: map['series_id'] as String?,
      recurringSeriesId: map['recurring_series_id'] as String?,
      trainerName: map['trainer_name'] as String?,
      childId: map['child_id'] as String?,
      childFirstName: map['child_first_name'] as String?,
      childLastName: map['child_last_name'] as String?,
      parentName: map['parent_name'] as String?,
      attendanceStatus: map['attendance_status'] as String?,
      attendanceObservation: map['attendance_observation'] as String?,
      creditedSeriesId: map['credited_series_id'] as String?,
      visitorRegularDayOfWeek: map['visitor_regular_day_of_week'] as String?,
      visitorRegularStartTime: map['visitor_regular_start_time'] as String?,
      visitorRegularSeriesTitle: map['visitor_regular_series_title'] as String?,
    );
  }
}
