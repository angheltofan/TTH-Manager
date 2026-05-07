/// Aggregate summary of a child's current attendance cycle.
/// Parsed from the `child_current_status` view.
class ChildCurrentStatus {
  const ChildCurrentStatus({
    required this.childId,
    this.sessionsCount = 4,
    this.presentCount = 0,
    this.absentCount = 0,
    this.motivatedCount = 0,
    this.workshopType,
    this.cycleStart,
  });

  final String childId;
  final int sessionsCount;
  final int presentCount;
  final int absentCount;
  final int motivatedCount;
  final String? workshopType;
  final DateTime? cycleStart;

  int get remaining =>
      (sessionsCount - presentCount).clamp(0, sessionsCount);
  bool get isComplete => presentCount >= sessionsCount;
  double get progress =>
      sessionsCount > 0 ? (presentCount / sessionsCount).clamp(0.0, 1.0) : 0.0;

  factory ChildCurrentStatus.fromMap(Map<String, dynamic> map) =>
      ChildCurrentStatus(
        childId: (map['child_id'] as String?) ?? '',
        sessionsCount: (map['sessions_count'] as num?)?.toInt() ?? 4,
        presentCount: (map['present_count'] as num?)?.toInt() ?? 0,
        absentCount: (map['absent_count'] as num?)?.toInt() ?? 0,
        motivatedCount: (map['motivated_count'] as num?)?.toInt() ?? 0,
        workshopType: map['workshop_type'] as String?,
        cycleStart: map['cycle_start'] != null
            ? DateTime.tryParse(map['cycle_start'] as String)
            : null,
      );
}
