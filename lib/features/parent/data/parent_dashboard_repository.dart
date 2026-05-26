import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/parent_dashboard.dart';

/// Read-only data layer for the parent dashboard. All queries are
/// scoped by the P2 RLS policies — a parent only sees rows for children
/// linked via `child_parents` to their own `auth.uid()`.
class ParentDashboardRepository {
  const ParentDashboardRepository(this._client);

  final SupabaseClient _client;

  // ── Linked children with per-child summary ─────────────────────────────────

  Future<List<ParentDashboardChild>> getLinkedChildren({
    required String parentId,
  }) async {
    final linkRows = await _client
        .from('child_parents')
        .select(
          'relationship, is_primary, created_at, '
          'children!child_id(id, first_name, last_name, is_active)',
        )
        .eq('parent_id', parentId)
        .order('is_primary', ascending: false)
        .order('created_at', ascending: true);

    final basics = <_ChildBasics>[];
    for (final row in (linkRows as List).cast<Map<String, dynamic>>()) {
      final child = row['children'] as Map<String, dynamic>?;
      if (child == null) continue;
      if (child['is_active'] == false) continue;
      basics.add(_ChildBasics(
        id: child['id'] as String,
        firstName: (child['first_name'] as String?) ?? '',
        lastName: (child['last_name'] as String?) ?? '',
        relationship: row['relationship'] as String?,
        isPrimary: (row['is_primary'] as bool?) ?? false,
      ));
    }

    // Fetch per-child stats in parallel.
    final summaries = await Future.wait(basics.map(_buildSummary));
    return summaries;
  }

  Future<ParentDashboardChild> _buildSummary(_ChildBasics basics) async {
    final results = await Future.wait([
      _client
          .from('workshop_enrollments')
          .select('id')
          .eq('child_id', basics.id)
          .eq('is_active', true),
      _client
          .from('attendance')
          .select('id')
          .eq('child_id', basics.id)
          .eq('status', 'present')
          .filter('payment_cycle_id', 'is', null)
          .eq('is_archived', false),
      _client
          .from('payment_cycles')
          .select('status, created_at')
          .eq('child_id', basics.id)
          .order('created_at', ascending: false)
          .limit(1),
    ]);

    final enrollments = (results[0] as List);
    final presents = (results[1] as List);
    final cycles = (results[2] as List).cast<Map<String, dynamic>>();
    final paymentStatus =
        cycles.isNotEmpty ? cycles.first['status'] as String? : null;

    return ParentDashboardChild(
      id: basics.id,
      firstName: basics.firstName,
      lastName: basics.lastName,
      relationship: basics.relationship,
      isPrimary: basics.isPrimary,
      activeWorkshopCount: enrollments.length,
      currentCyclePresent: presents.length,
      paymentStatus: paymentStatus,
    );
  }

  // ── Next scheduled workshop for a child ────────────────────────────────────

  Future<ParentNextWorkshop?> getNextWorkshop(String childId) async {
    final enrollments = await _client
        .from('workshop_enrollments')
        .select('series_id')
        .eq('child_id', childId)
        .eq('is_active', true);

    final seriesIds = (enrollments as List)
        .map((r) => (r as Map<String, dynamic>)['series_id'] as String?)
        .whereType<String>()
        .toList();
    if (seriesIds.isEmpty) return null;

    final idList = '(${seriesIds.map((s) => '"$s"').join(',')})';
    final today = DateTime.now();
    final todayStr =
        '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';

    final data = await _client
        .from('scheduled_workshops')
        .select(
          'id, title, workshop_type, workshop_date, day_of_week, '
          'start_time, end_time, is_active',
        )
        // The P2 RLS already handles series_id ↔ recurring_series_id
        // fallback; both column lookups are unioned here client-side.
        .or('series_id.in.$idList,recurring_series_id.in.$idList')
        .gte('workshop_date', todayStr)
        .eq('is_active', true)
        .order('workshop_date', ascending: true)
        .order('start_time', ascending: true)
        .limit(1);

    final rows = (data as List).cast<Map<String, dynamic>>();
    if (rows.isEmpty) return null;
    return ParentNextWorkshop.fromMap(rows.first);
  }

  // ── Recent activity for a child ────────────────────────────────────────────

  Future<ParentRecentActivity> getRecentActivity({
    required String childId,
    required String parentId,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final results = await Future.wait([
      _client
          .from('attendance')
          .select(
            'id, status, marked_at, '
            'scheduled_workshops!scheduled_workshop_id('
            'title, workshop_date)',
          )
          .eq('child_id', childId)
          .eq('is_archived', false)
          .order('marked_at', ascending: false)
          .limit(1),
      _client
          .from('payment_cycles')
          .select('id, status, paid_at, period_start, period_end, created_at')
          .eq('child_id', childId)
          .order('created_at', ascending: false)
          .limit(1),
      _client
          .from('notifications')
          .select('id, title, body, is_read, created_at')
          .eq('recipient_id', parentId)
          .eq('related_child_id', childId)
          .or('expires_at.is.null,expires_at.gt.$nowIso')
          .order('created_at', ascending: false)
          .limit(1),
    ]);

    ParentRecentAttendance? attendance;
    final attRows = (results[0] as List).cast<Map<String, dynamic>>();
    if (attRows.isNotEmpty) {
      final r = attRows.first;
      final sw = r['scheduled_workshops'] as Map<String, dynamic>?;
      attendance = ParentRecentAttendance(
        id: r['id'] as String,
        status: r['status'] as String?,
        workshopTitle: sw?['title'] as String?,
        workshopDate: sw?['workshop_date'] != null
            ? DateTime.tryParse(sw!['workshop_date'] as String)
            : null,
      );
    }

    ParentRecentPayment? payment;
    final payRows = (results[1] as List).cast<Map<String, dynamic>>();
    if (payRows.isNotEmpty) {
      final r = payRows.first;
      payment = ParentRecentPayment(
        id: r['id'] as String,
        status: r['status'] as String?,
        paidAt: r['paid_at'] != null
            ? DateTime.tryParse(r['paid_at'] as String)
            : null,
        periodStart: r['period_start'] != null
            ? DateTime.tryParse(r['period_start'] as String)
            : null,
        periodEnd: r['period_end'] != null
            ? DateTime.tryParse(r['period_end'] as String)
            : null,
      );
    }

    ParentRecentNotification? notif;
    final notifRows = (results[2] as List).cast<Map<String, dynamic>>();
    if (notifRows.isNotEmpty) {
      final r = notifRows.first;
      notif = ParentRecentNotification(
        id: r['id'] as String,
        title: (r['title'] as String?) ?? '',
        body: r['body'] as String?,
        createdAt: r['created_at'] != null
            ? DateTime.tryParse(r['created_at'] as String)
            : null,
        isRead: (r['is_read'] as bool?) ?? false,
      );
    }

    return ParentRecentActivity(
      lastAttendance: attendance,
      lastPayment: payment,
      lastNotification: notif,
    );
  }

  // ── Active workshops for a child (for the read-only details page) ──────────

  Future<List<ParentNextWorkshop>> getActiveWorkshops(String childId) async {
    final enrollments = await _client
        .from('workshop_enrollments')
        .select('series_id')
        .eq('child_id', childId)
        .eq('is_active', true);

    final seriesIds = (enrollments as List)
        .map((r) => (r as Map<String, dynamic>)['series_id'] as String?)
        .whereType<String>()
        .toList();
    if (seriesIds.isEmpty) return [];

    final idList = '(${seriesIds.map((s) => '"$s"').join(',')})';
    final today = DateTime.now();
    final todayStr =
        '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';

    final data = await _client
        .from('scheduled_workshops')
        .select(
          'id, title, workshop_type, workshop_date, day_of_week, '
          'start_time, end_time, is_active, series_id, recurring_series_id',
        )
        .or('series_id.in.$idList,recurring_series_id.in.$idList')
        .gte('workshop_date', todayStr)
        .eq('is_active', true)
        .order('workshop_date', ascending: true)
        .order('start_time', ascending: true);

    // De-dupe by series so one row represents each series the child
    // is enrolled in (using the next upcoming instance for metadata).
    final seen = <String>{};
    final out = <ParentNextWorkshop>[];
    for (final row in (data as List).cast<Map<String, dynamic>>()) {
      final key =
          (row['series_id'] as String?) ?? (row['recurring_series_id'] as String?);
      if (key == null) continue;
      if (!seen.add(key)) continue;
      out.add(ParentNextWorkshop.fromMap(row));
    }
    return out;
  }

  // ── Child basic info (read-only) ───────────────────────────────────────────

  Future<Map<String, dynamic>?> getChildBasic(String childId) async {
    final data = await _client
        .from('children')
        .select('id, first_name, last_name, birth_date, is_active')
        .eq('id', childId)
        .maybeSingle();
    return data;
  }

  // ── Payment cycle history (read-only) ──────────────────────────────────────

  Future<List<Map<String, dynamic>>> getPaymentCycles(String childId) async {
    final data = await _client
        .from('payment_cycles')
        .select(
          'id, status, paid_at, period_start, period_end, '
          'sessions_count, payment_method, created_at',
        )
        .eq('child_id', childId)
        .order('created_at', ascending: false);
    return (data as List).cast<Map<String, dynamic>>();
  }
}

class _ChildBasics {
  const _ChildBasics({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.relationship,
    this.isPrimary = false,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String? relationship;
  final bool isPrimary;
}
