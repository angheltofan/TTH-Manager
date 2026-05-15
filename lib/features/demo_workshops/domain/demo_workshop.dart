/// Domain model for a row in `public.demo_workshops`.
class DemoWorkshop {
  const DemoWorkshop({
    required this.id,
    required this.childFirstName,
    required this.childLastName,
    this.parentName,
    this.parentPhone,
    this.parentEmail,
    required this.workshopType,
    required this.workshopTitle,
    required this.demoDate,
    required this.startTime,
    required this.endTime,
    required this.trainerId,
    this.trainerName,
    this.notes,
    required this.status,
    this.convertedChildId,
    this.convertedSeriesId,
    this.createdBy,
    this.createdAt,
  });

  final String id;
  final String childFirstName;
  final String childLastName;
  final String? parentName;
  final String? parentPhone;
  final String? parentEmail;
  final String workshopType;
  final String workshopTitle;
  final DateTime demoDate;
  final String startTime;
  final String endTime;
  final String trainerId;
  final String? trainerName;
  final String? notes;

  /// 'scheduled' | 'completed' | 'no_show' | 'cancelled' | 'converted'
  final String status;

  final String? convertedChildId;
  final String? convertedSeriesId;
  final String? createdBy;
  final DateTime? createdAt;

  String get childFullName => '$childFirstName $childLastName';

  bool get isScheduled => status == 'scheduled';
  bool get isConverted => status == 'converted';

  factory DemoWorkshop.fromMap(Map<String, dynamic> map) {
    // trainer name may come from a joined profiles row
    String? trainerName;
    final profileRaw = map['profiles'];
    if (profileRaw is Map) {
      final fn = (profileRaw['first_name'] as String?) ?? '';
      final ln = (profileRaw['last_name'] as String?) ?? '';
      final full = '$fn $ln'.trim();
      if (full.isNotEmpty) trainerName = full;
    }

    return DemoWorkshop(
      id: map['id'] as String,
      childFirstName: (map['child_first_name'] as String?) ?? '',
      childLastName: (map['child_last_name'] as String?) ?? '',
      parentName: map['parent_name'] as String?,
      parentPhone: map['parent_phone'] as String?,
      parentEmail: map['parent_email'] as String?,
      workshopType: (map['workshop_type'] as String?) ?? '',
      workshopTitle: (map['workshop_title'] as String?) ?? '',
      demoDate: DateTime.parse(map['demo_date'] as String),
      startTime: (map['start_time'] as String?) ?? '',
      endTime: (map['end_time'] as String?) ?? '',
      trainerId: (map['trainer_id'] as String?) ?? '',
      trainerName: trainerName,
      notes: map['notes'] as String?,
      status: (map['status'] as String?) ?? 'scheduled',
      convertedChildId: map['converted_child_id'] as String?,
      convertedSeriesId: map['converted_series_id'] as String?,
      createdBy: map['created_by'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
    );
  }
}
