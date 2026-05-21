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
    this.trainerName,
    this.childId,
    this.childFirstName,
    this.childLastName,
    this.parentName,
    this.attendanceStatus,
    this.attendanceObservation,
  });

  final String workshopId;
  final String title;
  final String workshopType;
  final DateTime workshopDate;
  final String dayOfWeek;
  final String startTime;
  final String endTime;
  final String trainerId;
  /// The recurring series id this scheduled workshop belongs to.
  /// Used to load and manage [workshop_enrollments].
  final String? seriesId;
  final String? trainerName;
  final String? childId;
  final String? childFirstName;
  final String? childLastName;
  final String? parentName;
  final String? attendanceStatus;
  final String? attendanceObservation;

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
      trainerName: map['trainer_name'] as String?,
      childId: map['child_id'] as String?,
      childFirstName: map['child_first_name'] as String?,
      childLastName: map['child_last_name'] as String?,
      parentName: map['parent_name'] as String?,
      attendanceStatus: map['attendance_status'] as String?,
      attendanceObservation: map['attendance_observation'] as String?,
    );
  }
}
