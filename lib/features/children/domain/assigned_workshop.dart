/// A workshop that a child is assigned to, enriched with trainer name.
/// Parsed from workshop_children → scheduled_workshops → profiles join.
class AssignedWorkshop {
  const AssignedWorkshop({
    required this.id,
    required this.title,
    this.workshopType,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.trainerId,
    this.trainerName,
    this.recurringSeriesId,
    this.workshopDate,
    this.isActive,
  });

  final String id;
  final String title;
  final String? workshopType;
  final String dayOfWeek;
  final String startTime;
  final String endTime;
  final String? trainerId;
  final String? trainerName;

  /// Identifies the recurring series this instance belongs to.
  /// If null, this workshop has no recurrence — use [id] as the key.
  final String? recurringSeriesId;

  /// The date of this specific weekly instance. Used only for dedup.
  final DateTime? workshopDate;

  /// Whether this instance is still active.
  final bool? isActive;

  /// Map comes from the `scheduled_workshops` node of the PostgREST join.
  /// Embedded `profiles` key provides trainer's first/last name.
  factory AssignedWorkshop.fromMap(Map<String, dynamic> map) {
    String? trainerName;
    final profileRaw = map['profiles'];
    if (profileRaw is Map) {
      final fn = (profileRaw['first_name'] as String?) ?? '';
      final ln = (profileRaw['last_name'] as String?) ?? '';
      final full = '$fn $ln'.trim();
      if (full.isNotEmpty) trainerName = full;
    }

    return AssignedWorkshop(
      id: map['id'] as String,
      title: (map['title'] as String?) ?? '',
      workshopType: map['workshop_type'] as String?,
      dayOfWeek: (map['day_of_week'] as String?) ?? '',
      startTime: (map['start_time'] as String?) ?? '',
      endTime: (map['end_time'] as String?) ?? '',
      trainerId: map['trainer_id'] as String?,
      trainerName: trainerName,
      recurringSeriesId: map['recurring_series_id'] as String?,
      workshopDate: map['workshop_date'] != null
          ? DateTime.tryParse(map['workshop_date'] as String)
          : null,
      isActive: map['is_active'] as bool?,
    );
  }

  // ── Deduplication ────────────────────────────────────────────────────────

  /// Collapse a flat list of weekly instances into one entry per series.
  ///
  /// Selection priority per group:
  ///   1. Current-week instance (Monday–Sunday of today's week)
  ///   2. Latest active instance by workshop_date
  ///   3. Latest instance by workshop_date
  static List<AssignedWorkshop> deduplicateBySeries(
      List<AssignedWorkshop> all) {
    if (all.isEmpty) return all;

    final now = DateTime.now();
    final monday =
        DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final sunday =
        DateTime(monday.year, monday.month, monday.day + 6, 23, 59, 59);

    final Map<String, List<AssignedWorkshop>> groups = {};
    for (final w in all) {
      final key = w.recurringSeriesId ?? w.id;
      groups.putIfAbsent(key, () => []).add(w);
    }

    return groups.values.map((group) {
      if (group.length == 1) return group.first;

      // 1. Current week instance
      final currentWeek = group.where((w) {
        final d = w.workshopDate;
        return d != null && !d.isBefore(monday) && !d.isAfter(sunday);
      }).toList();
      if (currentWeek.isNotEmpty) return currentWeek.first;

      // 2. Latest active
      final active = [...group.where((w) => w.isActive == true)]
        ..sort((a, b) => (b.workshopDate ?? DateTime(0))
            .compareTo(a.workshopDate ?? DateTime(0)));
      if (active.isNotEmpty) return active.first;

      // 3. Latest by date
      return ([...group]
            ..sort((a, b) => (b.workshopDate ?? DateTime(0))
                .compareTo(a.workshopDate ?? DateTime(0))))
          .first;
    }).toList();
  }
}
