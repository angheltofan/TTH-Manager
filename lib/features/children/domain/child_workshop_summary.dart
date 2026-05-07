/// A lightweight summary of a workshop series that a child is enrolled in.
/// Parsed from the PostgREST embedded join result of
/// `workshop_enrollments!child_id(workshop_series!series_id(...))`.
class ChildWorkshopSummary {
  const ChildWorkshopSummary({
    required this.id,
    required this.title,
    required this.workshopType,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.trainerId,
  });

  final String id;
  final String title;
  final String workshopType;
  final String dayOfWeek;
  final String startTime;
  final String endTime;
  final String trainerId;

  factory ChildWorkshopSummary.fromMap(Map<String, dynamic> map) {
    return ChildWorkshopSummary(
      id: map['id'] as String,
      title: map['title'] as String,
      workshopType: (map['workshop_type'] as String?) ?? '',
      dayOfWeek: (map['day_of_week'] as String?) ?? '',
      startTime: (map['start_time'] as String?) ?? '',
      endTime: (map['end_time'] as String?) ?? '',
      trainerId: (map['trainer_id'] as String?) ?? '',
    );
  }
}
