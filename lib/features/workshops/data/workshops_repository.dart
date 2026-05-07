import 'package:supabase_flutter/supabase_flutter.dart';

import '../../dashboard/domain/dashboard_workshop.dart';
import '../domain/scheduled_workshop.dart';
import '../domain/workshop_detail_row.dart';

class WorkshopsRepository {
  const WorkshopsRepository(this._client);

  final SupabaseClient _client;

  /// Fetches all workshops with trainer name + children count from the
  /// `dashboard_workshops` view (no date filter — full list).
  Future<List<DashboardWorkshop>> getAllWorkshops() async {
    final data = await _client
        .from('dashboard_workshops')
        .select()
        .order('workshop_date')
        .order('start_time');
    final list = (data as List)
        .map((e) => DashboardWorkshop.fromMap(e as Map<String, dynamic>))
        .toList();

    // Sort client-side: chronological by actual date then start time.
    // The view may order day_of_week alphabetically in Romanian
    // (JOI < LUNI < MARTI < MIERCURI < VINERI) instead of Mon–Fri.
    list.sort((a, b) {
      final dateCmp = a.workshopDate.compareTo(b.workshopDate);
      if (dateCmp != 0) return dateCmp;
      return a.startTime.compareTo(b.startTime);
    });

    return list;
  }

  Future<List<ScheduledWorkshop>> getAll() async {
    final data = await _client
        .from('scheduled_workshops')
        .select()
        .order('workshop_date');
    return (data as List)
        .map((e) => ScheduledWorkshop.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Loads children for a workshop occurrence using series-level enrollment.
  ///
  /// For recurring workshops: queries [workshop_enrollments] by [recurring_series_id].
  /// Attendance is scoped to this specific occurrence only.
  Future<List<WorkshopDetailRow>> getDetails(String workshopId) async {
    // 1. Workshop metadata + trainer name
    final wsData = await _client
        .from('scheduled_workshops')
        .select(
          'id, title, workshop_type, workshop_date, day_of_week, '
          'start_time, end_time, trainer_id, recurring_series_id, is_active, '
          'profiles!trainer_id(first_name, last_name)',
        )
        .eq('id', workshopId)
        .maybeSingle();
    if (wsData == null) return [];

    final seriesId = wsData['recurring_series_id'] as String?;

    // 2. Children enrolled in this series via workshop_enrollments
    final childMap = <String, Map<String, dynamic>>{};
    if (seriesId != null) {
      final enrollmentData = await _client
          .from('workshop_enrollments')
          .select(
              'child_id, children!child_id(id, first_name, last_name, parent_phone)')
          .eq('series_id', seriesId)
          .eq('is_active', true);

      for (final row in (enrollmentData as List)) {
        final childId = row['child_id'] as String?;
        final child = row['children'] as Map<String, dynamic>?;
        if (childId != null &&
            child != null &&
            !childMap.containsKey(childId)) {
          childMap[childId] = child;
        }
      }
    }

    // 3. Attendance for THIS specific workshop occurrence
    final attData = await _client
        .from('attendance')
        .select('child_id, status, observation')
        .eq('scheduled_workshop_id', workshopId);

    final attMap = <String, Map<String, dynamic>>{};
    for (final row in (attData as List)) {
      attMap[row['child_id'] as String] = row as Map<String, dynamic>;
    }

    // 4. Trainer name
    String? trainerName;
    final profileRaw = wsData['profiles'];
    if (profileRaw is Map) {
      final fn = (profileRaw['first_name'] as String?) ?? '';
      final ln = (profileRaw['last_name'] as String?) ?? '';
      final full = '$fn $ln'.trim();
      if (full.isNotEmpty) trainerName = full;
    }

    // Shared workshop fields
    final wsId = wsData['id'] as String;
    final title = wsData['title'] as String;
    final workshopType = wsData['workshop_type'] as String;
    final workshopDate =
        DateTime.parse(wsData['workshop_date'] as String);
    final dayOfWeek = wsData['day_of_week'] as String;
    final startTime = wsData['start_time'] as String;
    final endTime = wsData['end_time'] as String;
    final trainerId = wsData['trainer_id'] as String;

    // 5. No enrolled children → return single metadata-only row
    if (childMap.isEmpty) {
      return [
        WorkshopDetailRow(
          workshopId: wsId,
          title: title,
          workshopType: workshopType,
          workshopDate: workshopDate,
          dayOfWeek: dayOfWeek,
          startTime: startTime,
          endTime: endTime,
          trainerId: trainerId,
          seriesId: seriesId,
          trainerName: trainerName,
        ),
      ];
    }

    return childMap.entries.map((entry) {
      final childId = entry.key;
      final child = entry.value;
      final att = attMap[childId];
      return WorkshopDetailRow(
        workshopId: wsId,
        title: title,
        workshopType: workshopType,
        workshopDate: workshopDate,
        dayOfWeek: dayOfWeek,
        startTime: startTime,
        endTime: endTime,
        trainerId: trainerId,
        seriesId: seriesId,
        trainerName: trainerName,
        childId: childId,
        childFirstName: child['first_name'] as String?,
        childLastName: child['last_name'] as String?,
        parentPhone: child['parent_phone'] as String?,
        attendanceStatus: att?['status'] as String?,
        attendanceObservation: att?['observation'] as String?,
      );
    }).toList();
  }

  Future<ScheduledWorkshop?> getById(String id) async {
    final data = await _client
        .from('scheduled_workshops')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return ScheduledWorkshop.fromMap(data);
  }

  Future<void> create(Map<String, dynamic> data) async {
    await _client.from('scheduled_workshops').insert(data);
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await _client.from('scheduled_workshops').update(data).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('scheduled_workshops').delete().eq('id', id);
  }

  /// Updates all future active workshops that share the same [recurringSeriesId],
  /// starting from [fromDate] (inclusive). Does NOT modify attendance records.
  Future<void> updateSeries({
    required String recurringSeriesId,
    required DateTime fromDate,
    required Map<String, dynamic> data,
  }) async {
    await _client
        .from('scheduled_workshops')
        .update(data)
        .eq('recurring_series_id', recurringSeriesId)
        .eq('is_active', true)
        .gte('workshop_date', fromDate.toIso8601String().split('T').first);
  }

  // ── Attendance ────────────────────────────────────────────────────────────

  Future<void> markAttendance({
    required String workshopId,
    required String childId,
    required String status,
    String? observation,
    required String markedBy,
  }) async {
    await _client.from('attendance').upsert(
      {
        'scheduled_workshop_id': workshopId,
        'child_id': childId,
        'status': status,
        'observation': observation,
        'marked_by': markedBy,
        'marked_at': DateTime.now().toUtc().toIso8601String(),
        'is_archived': false,
      },
      onConflict: 'scheduled_workshop_id,child_id',
    );
  }
}

