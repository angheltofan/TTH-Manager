import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/parent_base.dart';
import '../domain/parent_dashboard.dart';

/// Read-only data layer for the parent dashboard. All queries are
/// scoped by the P2 RLS policies — a parent only sees rows for children
/// linked via `child_parents` to their own `auth.uid()`.
///
/// Trainer-name JOINs are best-effort: parent has no SELECT on staff
/// `profiles` rows, so the embedded object comes back null. Callers
/// treat that as "trainer hidden" rather than an error.
///
/// Phase 1 of the perf refactor split the API into two layers:
///   • [getLinkedChildrenBase] — one `child_parents + children` query,
///     consumed by every downstream provider so the lookup never
///     repeats per first paint.
///   • [getEnrollmentsForBase] — one `workshop_enrollments` query for
///     the entire linked-child set.
///   • Per-section methods (next workshop, attendance rate, recent
///     activity, weekly schedule, per-child summary) all accept the
///     pre-loaded base / enrollments object so they only issue the
///     final query that actually fetches their data.
class ParentDashboardRepository {
  const ParentDashboardRepository(this._client);

  final SupabaseClient _client;

  // ── Base (single child_parents + children JOIN) ────────────────────────────

  /// ONE query that returns the parent's active linked children plus
  /// the data needed to render names and ordering. Single source of
  /// truth — every downstream method takes the result of this call as
  /// input.
  ///
  /// `child_parents.relationship` is intentionally NOT selected
  /// (product rule — never display or transport on the parent client).
  Future<ParentBase> getLinkedChildrenBase(String parentId) async {
    final linkRows = await _client
        .from('child_parents')
        .select(
          'is_primary, created_at, '
          'children!child_id(id, first_name, last_name, is_active, payment_type)',
        )
        .eq('parent_id', parentId)
        .order('is_primary', ascending: false)
        .order('created_at', ascending: true);

    final basics = <ParentChildBasic>[];
    final childOrder = <String>[];
    final childById = <String, ParentChildBasic>{};

    for (final row in (linkRows as List).cast<Map<String, dynamic>>()) {
      final child = row['children'] as Map<String, dynamic>?;
      if (child == null) continue;
      if (child['is_active'] == false) continue;
      final id = child['id'] as String?;
      if (id == null) continue;
      final basic = ParentChildBasic(
        id: id,
        firstName: (child['first_name'] as String?) ?? '',
        lastName: (child['last_name'] as String?) ?? '',
        isActive: true,
        isPrimary: (row['is_primary'] as bool?) ?? false,
        paymentType: (child['payment_type'] as String?) ?? 'paid',
      );
      basics.add(basic);
      childOrder.add(id);
      childById[id] = basic;
    }

    return ParentBase(
      basics: basics,
      childOrder: childOrder,
      childById: childById,
    );
  }

  // ── Enrollments base (single workshop_enrollments query) ───────────────────

  /// ONE query that returns active enrollments for every linked child.
  /// Drives both per-child series IDs (no per-child enrollment lookup
  /// in `buildSummaryForChild` anymore) and the series-to-children
  /// rollup used by the next-workshop summary and weekly schedule.
  Future<ParentEnrollmentsBase> getEnrollmentsForBase(ParentBase base) async {
    if (base.isEmpty) return ParentEnrollmentsBase.empty;

    final rows = await _client
        .from('workshop_enrollments')
        .select('child_id, series_id')
        .inFilter('child_id', base.childIds)
        .eq('is_active', true);

    final childrenBySeries = <String, List<String>>{};
    final seriesByChild = <String, List<String>>{};
    for (final row in (rows as List).cast<Map<String, dynamic>>()) {
      final cid = row['child_id'] as String?;
      final sid = row['series_id'] as String?;
      if (cid == null || sid == null) continue;
      childrenBySeries.putIfAbsent(sid, () => []).add(cid);
      seriesByChild.putIfAbsent(cid, () => []).add(sid);
    }

    return ParentEnrollmentsBase(
      seriesIds: childrenBySeries.keys.toList(),
      childrenBySeries: childrenBySeries,
      seriesByChild: seriesByChild,
    );
  }

  // ── Per-child summary (4 queries in parallel, no enrollments query) ────────

  /// Builds the dashboard summary for one child given the child's
  /// active series IDs (already loaded by `getEnrollmentsForBase`).
  /// Fires four queries in a single `Future.wait` — attendance count,
  /// latest payment cycle, workshop snapshot, next session. Replaces
  /// the pre-Phase-1 `_buildSummary` which ran two of those queries
  /// sequentially.
  Future<ParentDashboardChild> buildSummaryForChild(
    ParentChildBasic basic,
    List<String> seriesIds,
  ) async {
    final isFree = basic.isFreeParticipant;

    // Free participants never have a `payment_cycles` row written —
    // a BEFORE INSERT trigger blocks it — so the queries we need are
    // slightly different on the two paths:
    //
    //   • paid:  count of present attendance rows whose payment_cycle_id
    //            is still NULL (the server clears it back to NULL by
    //            relinking after each closed cycle, so this count is
    //            implicitly windowed to the current open block);
    //   • free:  the SAME query without the present-only filter, plus a
    //            client-side walk that resets the running counter every
    //            time it hits 4 — see [_countOpenPresentBlock]. The
    //            server cannot reset for us because there is no cycle
    //            to attach the rows to.
    //
    // The payment_cycles query is skipped entirely for free participants
    // so they never accidentally surface stale legacy rows.
    final futures = <Future<dynamic>>[
      isFree
          ? _client
              .from('attendance')
              .select('id, status, scheduled_workshops!scheduled_workshop_id(workshop_date, start_time)')
              .eq('child_id', basic.id)
              .eq('is_archived', false)
          : _client
              .from('attendance')
              .select('id')
              .eq('child_id', basic.id)
              .eq('status', 'present')
              .filter('payment_cycle_id', 'is', null)
              .eq('is_archived', false),
      if (!isFree)
        _client
            .from('payment_cycles')
            .select('status, payment_method, paid_at, created_at')
            .eq('child_id', basic.id)
            .order('created_at', ascending: false)
            .limit(1),
      _fetchAnyRowForSeries(seriesIds),
      _fetchNextSessionForSeries(seriesIds),
    ];
    final results = await Future.wait<dynamic>(futures);

    final int currentCyclePresent;
    final String? paymentStatus;
    final String? paymentMethod;
    final DateTime? paymentPaidAt;
    final ParentNextWorkshop? snapshot;
    final ParentNextWorkshop? futureRow;

    if (isFree) {
      currentCyclePresent = _countOpenPresentBlock(
        (results[0] as List).cast<Map<String, dynamic>>(),
      );
      paymentStatus = null;
      paymentMethod = null;
      paymentPaidAt = null;
      snapshot = results[1] as ParentNextWorkshop?;
      futureRow = results[2] as ParentNextWorkshop?;
    } else {
      currentCyclePresent = (results[0] as List).length;
      final cycles = (results[1] as List).cast<Map<String, dynamic>>();
      final cycle = cycles.isNotEmpty ? cycles.first : null;
      paymentStatus = cycle?['status'] as String?;
      paymentMethod = cycle?['payment_method'] as String?;
      paymentPaidAt = cycle?['paid_at'] != null
          ? DateTime.tryParse(cycle!['paid_at'] as String)
          : null;
      snapshot = results[2] as ParentNextWorkshop?;
      futureRow = results[3] as ParentNextWorkshop?;
    }

    final primaryWorkshop = snapshot == null
        ? null
        : ParentChildWorkshopBrief(
            title: snapshot.title,
            workshopType: snapshot.workshopType,
            dayOfWeek: snapshot.dayOfWeek,
            startTime: snapshot.startTime,
            endTime: snapshot.endTime,
            trainerName: snapshot.trainerName,
          );

    return ParentDashboardChild(
      id: basic.id,
      firstName: basic.firstName,
      lastName: basic.lastName,
      isPrimary: basic.isPrimary,
      paymentType: basic.paymentType,
      activeWorkshopCount: seriesIds.length,
      currentCyclePresent: currentCyclePresent,
      paymentStatus: paymentStatus,
      paymentMethod: paymentMethod,
      paymentPaidAt: paymentPaidAt,
      primaryWorkshop: primaryWorkshop,
      nextWorkshopDate: futureRow?.workshopDate,
    );
  }

  /// Counts present rows since the most-recent 4th-present row.
  /// Walks chronologically (workshop_date asc, start_time asc); each
  /// time the running counter hits four, it resets to zero. The
  /// trailing value is what the dashboard shows as the "X" in "X / 4".
  ///
  /// Used only for free participants — paid children get the same
  /// reset for free server-side because the payment_cycle trigger
  /// links each closed block of four rows and clears their
  /// payment_cycle_id pool back to empty.
  int _countOpenPresentBlock(List<Map<String, dynamic>> rows) {
    final ordered = [...rows];
    ordered.sort((a, b) {
      final sa = a['scheduled_workshops'] as Map<String, dynamic>?;
      final sb = b['scheduled_workshops'] as Map<String, dynamic>?;
      final da = (sa?['workshop_date'] as String?) ?? '';
      final db = (sb?['workshop_date'] as String?) ?? '';
      final cmp = da.compareTo(db);
      if (cmp != 0) return cmp;
      final ta = (sa?['start_time'] as String?) ?? '';
      final tb = (sb?['start_time'] as String?) ?? '';
      return ta.compareTo(tb);
    });
    var count = 0;
    for (final r in ordered) {
      if (r['status'] == 'present') {
        count += 1;
        if (count == 4) count = 0;
      }
    }
    return count;
  }

  // ── Next scheduled workshop across ALL linked children ─────────────────────

  /// Soonest upcoming `scheduled_workshops` row among the parent's
  /// linked active children. Consumes the pre-loaded base + enrollments
  /// so it does not re-query `child_parents` or `workshop_enrollments`.
  Future<ParentNextWorkshopSummary?> getNextWorkshopSummary(
    ParentBase base,
    ParentEnrollmentsBase enrollments,
  ) async {
    if (enrollments.isEmpty) return null;

    final seriesIds = enrollments.seriesIds;
    final idList = '(${seriesIds.map((s) => '"$s"').join(',')})';
    final todayStr = _isoDateOnly(DateTime.now());

    final data = await _client
        .from('scheduled_workshops')
        .select(
          'id, title, workshop_type, workshop_date, day_of_week, '
          'start_time, end_time, series_id, recurring_series_id',
        )
        .or('series_id.in.$idList,recurring_series_id.in.$idList')
        .gte('workshop_date', todayStr)
        .eq('is_active', true)
        .order('workshop_date', ascending: true)
        .order('start_time', ascending: true)
        .limit(5);

    final rows = (data as List).cast<Map<String, dynamic>>();

    // First-name lookup table for the rollup, in primary-first order.
    final childById = <String, String>{
      for (final b in base.basics) b.id: b.firstName,
    };

    if (rows.isEmpty) {
      final fallback = await _fetchAnyRowForSeries(seriesIds);
      if (fallback == null) return null;
      final fbNames = _namesAttendingSeries(
        scheduledRowSeriesKey: null,
        childrenBySeries: enrollments.childrenBySeries,
        childById: childById,
        childOrder: base.childOrder,
        fallbackAllChildren: true,
      );
      return ParentNextWorkshopSummary(
        scheduledWorkshopId: fallback.id,
        title: fallback.title,
        workshopType: fallback.workshopType,
        workshopDate: null,
        dayOfWeek: fallback.dayOfWeek,
        startTime: fallback.startTime,
        endTime: fallback.endTime,
        childNames: fbNames,
        additionalUpcomingCount: 0,
      );
    }

    final head = rows.first;
    final seriesKey = (head['series_id'] as String?) ??
        (head['recurring_series_id'] as String?);
    final names = _namesAttendingSeries(
      scheduledRowSeriesKey: seriesKey,
      childrenBySeries: enrollments.childrenBySeries,
      childById: childById,
      childOrder: base.childOrder,
      fallbackAllChildren: false,
    );

    final additional = rows.length - 1;

    return ParentNextWorkshopSummary(
      scheduledWorkshopId: head['id'] as String,
      title: head['title'] as String?,
      workshopType: head['workshop_type'] as String?,
      workshopDate: head['workshop_date'] != null
          ? DateTime.tryParse(head['workshop_date'] as String)
          : null,
      dayOfWeek: head['day_of_week'] as String?,
      startTime: head['start_time'] as String?,
      endTime: head['end_time'] as String?,
      childNames: names,
      additionalUpcomingCount: additional < 0 ? 0 : additional,
    );
  }

  /// First names of the parent's children attending the row's series,
  /// preserving primary-first order. When the row's `series_id` is
  /// unknown (fallback path), lists all enrolled children so the KPI
  /// still has a child context.
  List<String> _namesAttendingSeries({
    required String? scheduledRowSeriesKey,
    required Map<String, List<String>> childrenBySeries,
    required Map<String, String> childById,
    required List<String> childOrder,
    required bool fallbackAllChildren,
  }) {
    Iterable<String> attendingIds;
    if (scheduledRowSeriesKey != null) {
      attendingIds = childrenBySeries[scheduledRowSeriesKey] ??
          const <String>[];
    } else if (fallbackAllChildren) {
      attendingIds = {
        for (final ids in childrenBySeries.values) ...ids,
      };
    } else {
      attendingIds = const <String>[];
    }
    final out = <String>[];
    for (final cid in childOrder) {
      if (!attendingIds.contains(cid)) continue;
      final n = childById[cid];
      if (n != null && n.isNotEmpty) out.add(n);
    }
    return out;
  }

  // ── Attendance-rate summary (3 parallel per-status queries) ────────────────

  /// Counts of `attendance` rows in the last 30 days across the
  /// parent's linked active children, broken down by status. Fires
  /// **three queries in parallel**, one per status, each selecting
  /// only `id` (no `status` text, no joined columns) so the payload is
  /// the minimum the PostgREST API supports. Consumes pre-loaded child
  /// IDs (no `child_parents` lookup).
  ///
  /// Implementation note: a true server-side count would be cleaner,
  /// but the supabase_flutter 2.x `.count(CountOption.exact)` terminal
  /// returns a `PostgrestResponse` (data + count tuple), not a plain
  /// integer, and pulling `.count` off the response while still
  /// transferring rows defeats the purpose. The selected `id`-only
  /// projection keeps each row to ≈ 36 bytes UUID + JSON overhead,
  /// which is the safest pattern that compiles cleanly across the
  /// supabase_flutter versions the project targets.
  Future<ParentAttendanceRateSummary> getAttendanceRateSummaryForIds(
    List<String> childIds,
  ) async {
    if (childIds.isEmpty) return const ParentAttendanceRateSummary.empty();

    final since = DateTime.now()
        .subtract(const Duration(days: 30))
        .toUtc()
        .toIso8601String();

    Future<int> countByStatus(String status) async {
      final data = await _client
          .from('attendance')
          .select('id')
          .inFilter('child_id', childIds)
          .eq('is_archived', false)
          .gte('marked_at', since)
          .eq('status', status);
      return (data as List).length;
    }

    final results = await Future.wait([
      countByStatus('present'),
      countByStatus('absent'),
      countByStatus('motivated'),
    ]);

    final p = results[0];
    final a = results[1];
    final m = results[2];
    final total = p + a + m;
    return ParentAttendanceRateSummary(
      presentCount: p,
      absentCount: a,
      motivatedCount: m,
      totalCount: total,
      ratePercent: total == 0 ? null : (p / total) * 100.0,
    );
  }

  // ── Recent activity for the parent's children ──────────────────────────────

  /// Last [limit] non-archived attendance rows across the parent's
  /// linked children. Consumes pre-loaded child IDs (no
  /// `child_parents` lookup).
  Future<List<ParentRecentActivityItem>> getRecentActivityForIds(
    List<String> childIds, {
    int limit = 3,
  }) async {
    if (childIds.isEmpty) return const [];

    final data = await _client
        .from('attendance')
        .select(
          'id, status, marked_at, child_id, observation, '
          'children!child_id(first_name, last_name), '
          'scheduled_workshops!scheduled_workshop_id('
          'title, workshop_type, workshop_date, day_of_week, '
          'start_time, end_time)',
        )
        .inFilter('child_id', childIds)
        .eq('is_archived', false)
        .order('marked_at', ascending: false)
        .limit(limit);

    final out = <ParentRecentActivityItem>[];
    for (final row in (data as List).cast<Map<String, dynamic>>()) {
      final c = row['children'] as Map<String, dynamic>?;
      final sw = row['scheduled_workshops'] as Map<String, dynamic>?;
      out.add(ParentRecentActivityItem(
        id: row['id'] as String,
        childId: (row['child_id'] as String?) ?? '',
        childFirstName: (c?['first_name'] as String?) ?? '',
        childLastName: (c?['last_name'] as String?) ?? '',
        status: row['status'] as String?,
        workshopTitle: sw?['title'] as String?,
        workshopType: sw?['workshop_type'] as String?,
        workshopDate: sw?['workshop_date'] != null
            ? DateTime.tryParse(sw!['workshop_date'] as String)
            : null,
        dayOfWeek: sw?['day_of_week'] as String?,
        startTime: sw?['start_time'] as String?,
        endTime: sw?['end_time'] as String?,
        markedAt: row['marked_at'] != null
            ? DateTime.tryParse(row['marked_at'] as String)
            : null,
        observation: row['observation'] as String?,
      ));
    }
    return out;
  }

  // ── Weekly schedule (one scheduled_workshops query, base in) ───────────────

  /// Returns one row per `scheduled_workshop_id` for sessions occurring
  /// in `[weekStart, weekEnd]` (inclusive). When multiple of the
  /// parent's children attend the same session, their first names are
  /// rolled up in `childFirstNames`. Consumes pre-loaded base +
  /// enrollments so no `child_parents` or `workshop_enrollments`
  /// queries are issued here.
  Future<List<ParentWeeklySession>> getWeeklyScheduleForBase(
    ParentBase base,
    ParentEnrollmentsBase enrollments, {
    required DateTime weekStart,
    required DateTime weekEnd,
  }) async {
    if (enrollments.isEmpty) return const [];

    final seriesIds = enrollments.seriesIds;
    final idList = '(${seriesIds.map((s) => '"$s"').join(',')})';
    final fromStr = _isoDateOnly(weekStart);
    final toStr = _isoDateOnly(weekEnd);

    final data = await _client
        .from('scheduled_workshops')
        .select(
          'id, title, workshop_type, workshop_date, day_of_week, '
          'start_time, end_time, series_id, recurring_series_id, '
          'profiles!trainer_id(first_name, last_name)',
        )
        .or('series_id.in.$idList,recurring_series_id.in.$idList')
        .gte('workshop_date', fromStr)
        .lte('workshop_date', toStr)
        .eq('is_active', true)
        .order('workshop_date', ascending: true)
        .order('start_time', ascending: true);

    final out = <ParentWeeklySession>[];
    for (final row in (data as List).cast<Map<String, dynamic>>()) {
      final sid = (row['series_id'] as String?) ??
          (row['recurring_series_id'] as String?);
      if (sid == null) continue;

      // Children attending this session in primary-first order.
      final attendingIds =
          enrollments.childrenBySeries[sid] ?? const <String>[];
      final names = <String>[];
      for (final cid in base.childOrder) {
        if (!attendingIds.contains(cid)) continue;
        final n = base.childById[cid]?.firstName ?? '';
        if (n.isNotEmpty) names.add(n);
      }

      final trainer = row['profiles'] as Map<String, dynamic>?;
      String? trainerName;
      if (trainer != null) {
        final f = (trainer['first_name'] as String?)?.trim() ?? '';
        final l = (trainer['last_name'] as String?)?.trim() ?? '';
        final composed = ('$f $l').trim();
        trainerName = composed.isEmpty ? null : composed;
      }

      out.add(ParentWeeklySession(
        scheduledWorkshopId: row['id'] as String,
        title: row['title'] as String?,
        workshopType: row['workshop_type'] as String?,
        workshopDate: row['workshop_date'] != null
            ? DateTime.tryParse(row['workshop_date'] as String)
            : null,
        dayOfWeek: row['day_of_week'] as String?,
        startTime: row['start_time'] as String?,
        endTime: row['end_time'] as String?,
        trainerName: trainerName,
        childFirstNames: names,
      ));
    }
    return out;
  }

  // ── Internal helpers (workshop_series snapshots) ───────────────────────────

  /// Shared lookup: soonest upcoming `scheduled_workshops` row for the
  /// given set of series IDs.
  Future<ParentNextWorkshop?> _fetchNextSessionForSeries(
    List<String> seriesIds,
  ) async {
    if (seriesIds.isEmpty) return null;
    final idList = '(${seriesIds.map((s) => '"$s"').join(',')})';
    final todayStr = _isoDateOnly(DateTime.now());

    final data = await _client
        .from('scheduled_workshops')
        .select(
          'id, title, workshop_type, workshop_date, day_of_week, '
          'start_time, end_time, is_active, '
          'profiles!trainer_id(first_name, last_name)',
        )
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

  /// "Active-workshop snapshot" lookup: returns the most recent
  /// `scheduled_workshops` row for the given series IDs regardless of
  /// date. Used by the child-card resolver and the "Următorul atelier"
  /// KPI's fallback path so the parent always sees the workshop's
  /// metadata even when the weekly generator hasn't materialised a
  /// future row yet.
  Future<ParentNextWorkshop?> _fetchAnyRowForSeries(
    List<String> seriesIds,
  ) async {
    if (seriesIds.isEmpty) return null;
    final idList = '(${seriesIds.map((s) => '"$s"').join(',')})';

    final data = await _client
        .from('scheduled_workshops')
        .select(
          'id, title, workshop_type, workshop_date, day_of_week, '
          'start_time, end_time, is_active, '
          'profiles!trainer_id(first_name, last_name)',
        )
        .or('series_id.in.$idList,recurring_series_id.in.$idList')
        .eq('is_active', true)
        .order('workshop_date', ascending: false)
        .order('start_time', ascending: false)
        .limit(1);

    final rows = (data as List).cast<Map<String, dynamic>>();
    if (rows.isEmpty) return null;
    return ParentNextWorkshop.fromMap(rows.first);
  }

  // ── ISO date helper ────────────────────────────────────────────────────────

  static String _isoDateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
