import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/weekday_utils.dart';
import '../../workshops/domain/workshop_series.dart';
import '../domain/demo_workshop.dart';

/// Outcome of [DemoWorkshopsRepository.convertDemoToEnrollment].
///
/// [enrollmentCreated] is false when the demo had already been converted
/// (idempotent re-call): the function returned the previously linked
/// child + series without writing.
class DemoConversionResult {
  const DemoConversionResult({
    required this.childId,
    required this.seriesId,
    required this.enrollmentCreated,
  });

  final String childId;
  final String seriesId;
  final bool enrollmentCreated;
}

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

  /// Looks for an existing **active** child with matching name + phone.
  ///
  /// Inactive (archived) children are excluded so the conversion picker
  /// does not silently re-attach a demo to an archived child. If the
  /// admin needs to re-link to an archived child they must reactivate
  /// it first from the children page.
  Future<Map<String, dynamic>?> findExistingChild({
    required String firstName,
    required String lastName,
    required String? phone,
  }) async {
    var query = _client
        .from('children')
        .select('id, first_name, last_name, parent_phone, is_active')
        .eq('is_active', true)
        .ilike('first_name', firstName)
        .ilike('last_name', lastName);
    if (phone != null && phone.isNotEmpty) {
      query = query.eq('parent_phone', phone);
    }
    final data = await query.limit(1).maybeSingle();
    return data;
  }

  /// Atomically converts a scheduled demo into a real enrollment.
  ///
  /// Wraps the previous 3-step Dart flow (createChild → enrollChild →
  /// markConverted) into a single transaction via the
  /// `convert_demo_to_enrollment` Postgres RPC (SECURITY INVOKER).
  ///
  /// The RPC:
  ///   • locks the demo row with FOR UPDATE,
  ///   • is idempotent: a second call on an already-converted demo returns
  ///     the existing linkage with [DemoConversionResult.enrollmentCreated]
  ///     false (no rows are written),
  ///   • creates a new child when [existingChildId] is null, otherwise
  ///     re-uses the provided child,
  ///   • upserts `workshop_enrollments(series_id, child_id)`,
  ///   • flips the demo to status='converted' and stores the linkage.
  Future<DemoConversionResult> convertDemoToEnrollment({
    required String demoId,
    required String seriesId,
    String? existingChildId,
  }) async {
    final raw = await _client.rpc(
      'convert_demo_to_enrollment',
      params: {
        'p_demo_id': demoId,
        'p_series_id': seriesId,
        'p_existing_child_id': existingChildId,
      },
    );
    final map = (raw as Map).cast<String, dynamic>();
    return DemoConversionResult(
      childId: map['child_id'] as String,
      seriesId: map['series_id'] as String,
      enrollmentCreated: (map['enrollment_created'] as bool?) ?? false,
    );
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
