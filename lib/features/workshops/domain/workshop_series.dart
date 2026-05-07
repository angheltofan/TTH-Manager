/// Domain model for a workshop series.
/// Parsed from the `workshop_series` table.
class WorkshopSeries {
  const WorkshopSeries({
    required this.id,
    required this.title,
    this.workshopType,
    this.dayOfWeek,
    required this.startTime,
    this.endTime,
    this.trainerId,
    this.trainerName,
    this.notes,
    this.isActive = true,
  });

  final String id;
  final String title;
  final String? workshopType;
  final String? dayOfWeek;
  final String startTime;
  final String? endTime;
  final String? trainerId;
  final String? trainerName;
  final String? notes;
  final bool isActive;

  factory WorkshopSeries.fromMap(Map<String, dynamic> map) {
    String? trainerName;
    final profileRaw = map['profiles'];
    if (profileRaw is Map) {
      final fn = (profileRaw['first_name'] as String?) ?? '';
      final ln = (profileRaw['last_name'] as String?) ?? '';
      final full = '$fn $ln'.trim();
      if (full.isNotEmpty) trainerName = full;
    }

    return WorkshopSeries(
      id: map['id'] as String,
      title: (map['title'] as String?) ?? '',
      workshopType: map['workshop_type'] as String?,
      dayOfWeek: map['day_of_week'] as String?,
      startTime: (map['start_time'] as String?) ?? '',
      endTime: map['end_time'] as String?,
      trainerId: map['trainer_id'] as String?,
      trainerName: trainerName,
      notes: map['notes'] as String?,
      isActive: (map['is_active'] as bool?) ?? true,
    );
  }
}
