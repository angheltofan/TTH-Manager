class ScheduledWorkshop {
  const ScheduledWorkshop({
    required this.id,
    required this.title,
    required this.workshopType,
    required this.workshopDate,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.trainerId,
    this.notes,
    this.isActive,
    this.isRecurring,
    this.recurringSeriesId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String workshopType;
  final DateTime workshopDate;
  final String dayOfWeek;
  final String startTime;
  final String endTime;
  final String trainerId;
  final String? notes;
  final bool? isActive;
  final bool? isRecurring;
  final String? recurringSeriesId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ScheduledWorkshop.fromMap(Map<String, dynamic> map) {
    return ScheduledWorkshop(
      id: map['id'] as String,
      title: map['title'] as String,
      workshopType: map['workshop_type'] as String,
      workshopDate: DateTime.parse(map['workshop_date'] as String),
      dayOfWeek: map['day_of_week'] as String,
      startTime: map['start_time'] as String,
      endTime: map['end_time'] as String,
      trainerId: map['trainer_id'] as String,
      notes: map['notes'] as String?,
      isActive: map['is_active'] as bool?,
      isRecurring: map['is_recurring'] as bool?,
      recurringSeriesId: map['recurring_series_id'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }
}
