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

  /// Dashboard today's demos. Previously filtered to `status =
  /// scheduled`, which meant a demo marked `completed` / `no_show` /
  /// `converted` during the day vanished from the Dashboard — the
  /// trainer couldn't tell at a glance who already showed up.
  ///
  /// New semantics: every demo scheduled for today EXCEPT `cancelled`
  /// — a cancelled demo is explicitly removed from the day and should
  /// not clutter the operational Dashboard. The outcome pill on each
  /// row ("Prezent" / "Absent" / "Înscris") communicates the state.
  /// The full history (including cancelled) stays accessible under
  /// `/demos` → Astăzi (via [getForDate]).
  ///
  /// Keep the SQL-side filter in sync with [isDashboardTodayVisible]
  /// — the predicate is the single source of truth for the inclusion
  /// rule and is checked by the regression tests.
  Future<List<DemoWorkshop>> getTodayDemos() async {
    final today = DateTime.now();
    final dateStr = _fmt(today);
    final data = await _client
        .from('demo_workshops')
        .select(_select)
        .eq('demo_date', dateStr)
        .neq('status', 'cancelled')
        .order('start_time');
    return _mapList(data);
  }

  /// Whether a demo with [status] belongs in the Dashboard's "today"
  /// list. True for every status operational trainers care about on
  /// the day (`scheduled`, `completed`, `no_show`, `converted`);
  /// false for `cancelled` since the demo was explicitly removed
  /// from the day. The regression test enforces this contract.
  static bool isDashboardTodayVisible(String status) =>
      status != 'cancelled';

  /// Every demo on [date], regardless of status. Powers the Demo-uri
  /// "Astăzi" tab — a demo marked `completed` / `no_show` / `converted`
  /// stays visible with its outcome shown as a status pill.
  Future<List<DemoWorkshop>> getForDate(DateTime date) async {
    final data = await _client
        .from('demo_workshops')
        .select(_select)
        .eq('demo_date', _fmt(date))
        .order('start_time');
    return _mapList(data);
  }

  /// Future demos (strictly after today), ordered chronologically
  /// ascending. Includes every status, so a scheduled demo cancelled
  /// in advance still surfaces in "Următoare" instead of silently
  /// vanishing.
  Future<List<DemoWorkshop>> getUpcoming() async {
    final data = await _client
        .from('demo_workshops')
        .select(_select)
        .gt('demo_date', _fmt(DateTime.now()))
        .order('demo_date')
        .order('start_time');
    return _mapList(data);
  }

  /// Past demos (strictly before today), newest first. Shows every
  /// historical demo including converted / cancelled / no_show so the
  /// admin can review the full lead journey.
  Future<List<DemoWorkshop>> getHistory() async {
    final data = await _client
        .from('demo_workshops')
        .select(_select)
        .lt('demo_date', _fmt(DateTime.now()))
        .order('demo_date', ascending: false)
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

  /// Reschedule contract: INSERT a NEW demo row carrying the original's
  /// child/parent/workshop/trainer metadata to a new date/time. The
  /// original row is left untouched so historical attendance stays in
  /// place — the lead journey from the first demo to the follow-up
  /// stays visible in "Istoric". Returns the new row's id so the UI
  /// can navigate to it (or scroll it into view) immediately.
  ///
  /// The caller is expected to resolve the original via [getById]
  /// first — this method takes only the fields it writes to avoid an
  /// extra round-trip, and to make the contract explicit.
  Future<String> reschedule({
    required DemoWorkshop original,
    required DateTime newDate,
    required String newStartTime,
    required String? newEndTime,
    required String createdBy,
  }) async {
    final payload = <String, dynamic>{
      'child_first_name': original.childFirstName,
      'child_last_name': original.childLastName,
      'parent_name': ?original.parentName,
      'parent_phone': ?original.parentPhone,
      'parent_email': ?original.parentEmail,
      'workshop_type': original.workshopType,
      'workshop_title': original.workshopTitle,
      'demo_date': _fmt(newDate),
      'start_time': newStartTime,
      'end_time': ?newEndTime,
      'trainer_id': original.trainerId,
      'notes': ?original.notes,
      'status': 'scheduled',
      'created_by': createdBy,
    };
    final result = await _client
        .from('demo_workshops')
        .insert(payload)
        .select('id')
        .single();
    return result['id'] as String;
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
