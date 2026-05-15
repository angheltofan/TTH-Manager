import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/weekday_utils.dart';
import '../../workshops/domain/workshop_series.dart';
import '../domain/demo_workshop.dart';

class DemoWorkshopsRepository {
  const DemoWorkshopsRepository(this._client);

  final SupabaseClient _client;

  static const _select =
      '*, profiles!trainer_id(first_name, last_name)';

  // ── Fetch ─────────────────────────────────────────────────────────────────

  Future<List<DemoWorkshop>> getTodayDemos() async {
    final today = DateTime.now();
    final dateStr = _fmt(today);
    final data = await _client
        .from('demo_workshops')
        .select(_select)
        .eq('demo_date', dateStr)
        .eq('status', 'scheduled')
        .order('start_time');
    return _mapList(data);
  }

  Future<List<DemoWorkshop>> getAllDemos() async {
    final data = await _client
        .from('demo_workshops')
        .select(_select)
        .order('demo_date', ascending: false)
        .order('start_time');
    return _mapList(data);
  }

  Future<DemoWorkshop?> getById(String id) async {
    final data = await _client
        .from('demo_workshops')
        .select(_select)
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return DemoWorkshop.fromMap(data);
  }

  // ── Workshop series for demo dropdown ──────────────────────────────────────

  /// Fetches active workshop series including trainer names, sorted Mon→Sun.
  Future<List<WorkshopSeries>> fetchActiveSeriesForDemo() async {
    final data = await _client
        .from('workshop_series')
        .select(
          'id, title, workshop_type, day_of_week, start_time, end_time, '
          'trainer_id, notes, is_active, '
          'profiles!trainer_id(first_name, last_name)',
        )
        .eq('is_active', true);
    return ((data as List)
        .map((e) => WorkshopSeries.fromMap(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => compareByWeekday(
            dayA: a.dayOfWeek,
            dayB: b.dayOfWeek,
            timeA: a.startTime,
            timeB: b.startTime,
            titleA: a.title,
            titleB: b.title,
          )));
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  Future<String> create(Map<String, dynamic> data) async {
    final result = await _client
        .from('demo_workshops')
        .insert(data)
        .select('id')
        .single();
    return result['id'] as String;
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await _client.from('demo_workshops').update(data).eq('id', id);
  }

  /// Marks status only (completed / no_show / cancelled).
  Future<void> updateStatus(String id, String status) async {
    await _client.from('demo_workshops').update({
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  // ── Conversion ────────────────────────────────────────────────────────────

  /// Looks for an existing active child with matching name + phone.
  Future<Map<String, dynamic>?> findExistingChild({
    required String firstName,
    required String lastName,
    required String? phone,
  }) async {
    var query = _client
        .from('children')
        .select('id, first_name, last_name, parent_phone, is_active')
        .ilike('first_name', firstName)
        .ilike('last_name', lastName);
    if (phone != null && phone.isNotEmpty) {
      query = query.eq('parent_phone', phone);
    }
    final data = await query.limit(1).maybeSingle();
    return data;
  }

  /// Creates a new child row and returns the new id.
  Future<String> createChild(Map<String, dynamic> childData) async {
    final result = await _client
        .from('children')
        .insert(childData)
        .select('id')
        .single();
    return result['id'] as String;
  }

  /// Enrolls a child into a workshop series (upsert to avoid duplicates).
  Future<void> enrollChild({
    required String childId,
    required String seriesId,
    required String enrolledBy,
  }) async {
    await _client.from('workshop_enrollments').upsert(
      {
        'child_id': childId,
        'series_id': seriesId,
        'is_active': true,
        'enrolled_by': enrolledBy,
        'enrolled_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'child_id,series_id',
    );
  }

  /// Marks the demo as converted and stores the linked child/series ids.
  Future<void> markConverted({
    required String demoId,
    required String childId,
    required String seriesId,
  }) async {
    await _client.from('demo_workshops').update({
      'status': 'converted',
      'converted_child_id': childId,
      'converted_series_id': seriesId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', demoId);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static List<DemoWorkshop> _mapList(dynamic data) {
    return (data as List)
        .map((e) => DemoWorkshop.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
