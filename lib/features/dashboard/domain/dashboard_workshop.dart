class DashboardWorkshop {
  const DashboardWorkshop({
    required this.id,
    required this.title,
    required this.workshopType,
    required this.workshopDate,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.trainerId,
    this.trainerName,
    this.childrenCount,
  });

  final String id;
  final String title;
  final String workshopType;
  final DateTime workshopDate;
  final String dayOfWeek;
  final String startTime;
  final String endTime;
  final String trainerId;
  final String? trainerName;
  final int? childrenCount;

  factory DashboardWorkshop.fromMap(Map<String, dynamic> map) {
    return DashboardWorkshop(
      id: map['id'] as String,
      title: map['title'] as String,
      workshopType: map['workshop_type'] as String,
      workshopDate: DateTime.parse(map['workshop_date'] as String),
      dayOfWeek: map['day_of_week'] as String,
      startTime: map['start_time'] as String,
      endTime: map['end_time'] as String,
      trainerId: map['trainer_id'] as String,
      trainerName: map['trainer_name'] as String?,
      childrenCount: (map['children_count'] as num?)?.toInt(),
    );
  }
}
