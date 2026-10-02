import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../afterschool/domain/afterschool_attendance.dart';
import '../../afterschool/domain/afterschool_enrollment.dart';
import '../../afterschool/domain/afterschool_month_attendance.dart';
import '../../afterschool/domain/afterschool_program.dart';
import '../../afterschool/domain/afterschool_session.dart';
import '../domain/child_activity_report.dart';

/// Data layer for the Child Activity Report PDF.
///
/// One public entry point: [fetchChildActivityReport] runs four bulk reads
/// in parallel (child info, active enrollments, full attendance history,
/// payment cycles) then assembles a single [ChildActivityReportData] for
/// the PDF service. No N+1 queries. RLS scopes results: admin sees all,
/// trainer sees only children in their assigned series.
class ChildReportRepository {
  const ChildReportRepository(this._client);

  final SupabaseClient _client;

  Future<ChildActivityReportData> fetchChildActivityReport(
      String childId) async {
    // Five parallel bulk reads: child row + workshop surface (3) +
    // afterschool enrollment metadata. The afterschool side needs
    // sessions + attendance based on the enrollment's program ids,
    // so those run in a second parallel step. Still no N+1.
    final firstStage = await Future.wait<dynamic>([
      _fetchChildRow(childId),
      _fetchActiveWorkshops(childId),
      _fetchAttendance(childId),
      _fetchPaymentCycles(childId),
      _fetchAfterschoolEnrollments(childId),
    ]);

    final childRow = firstStage[0] as Map<String, dynamic>?;
    if (childRow == null) {
      throw StateError('Child not found');
    }

    final workshops = firstStage[1] as List<ChildReportWorkshopInfo>;
    final workshopAttendance =
        firstStage[2] as List<ChildReportAttendanceRow>;
    final payments = firstStage[3] as List<ChildReportPaymentRow>;
    final afsEnrollmentBundle = firstStage[4] as AfterschoolEnrollmentBundle;

    // Second stage — depends on the program ids resolved above. Skip
    // the queries entirely when the child never participated in any
    // Afterschool program, so a workshop-only child costs the same
    // 4 round-trips as before.
    AfterschoolBundle afsBundle;
    if (afsEnrollmentBundle.enrollments.isEmpty) {
      afsBundle = AfterschoolBundle.empty();
    } else {
      final programIds = afsEnrollmentBundle.programsById.keys.toList();
      final secondStage = await Future.wait<dynamic>([
        _fetchAfterschoolSessions(programIds),
        _fetchAfterschoolAttendance(childId),
      ]);
      afsBundle = AfterschoolBundle(
        enrollments: afsEnrollmentBundle.enrollments,
        programsById: afsEnrollmentBundle.programsById,
        sessions: secondStage[0] as List<AfterschoolSession>,
        attendance: secondStage[1] as List<AfterschoolAttendance>,
      );
    }

    return assembleChildActivityReport(
      childInfo: _childInfoFromRow(childRow),
      activeWorkshops: workshops,
      workshopAttendance: workshopAttendance,
      payments: payments,
      afsBundle: afsBundle,
      childId: childId,
      today: DateTime.now(),
      generatedAt: DateTime.now(),
    );
  }

  // ── Queries ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> _fetchChildRow(String childId) async {
    return _client
        .from('children')
        .select(
            'id, first_name, last_name, birth_date, '
            'parent_name, parent_phone')
        .eq('id', childId)
        .maybeSingle();
  }

  Future<List<ChildReportWorkshopInfo>> _fetchActiveWorkshops(
      String childId) async {
    final data = await _client
        .from('workshop_enrollments')
        .select(
            'workshop_series!series_id('
            'title, workshop_type, day_of_week, start_time, end_time, '
            'profiles!trainer_id(first_name, last_name))')
        .eq('child_id', childId)
        .eq('is_active', true);

    final result = <ChildReportWorkshopInfo>[];
    for (final raw in (data as List)) {
      final ws = (raw as Map<String, dynamic>)['workshop_series'];
      if (ws is! Map) continue;
      result.add(_workshopInfoFromMap(ws.cast<String, dynamic>()));
    }
    return result;
  }

  Future<List<ChildReportAttendanceRow>> _fetchAttendance(
      String childId) async {
    final data = await _client
        .from('attendance')
        .select(
            'status, observation, marked_at, '
            'scheduled_workshops!scheduled_workshop_id('
            'title, workshop_type, workshop_date, '
            'start_time, end_time, '
            'profiles!trainer_id(first_name, last_name)))')
        .eq('child_id', childId)
        .eq('is_archived', false);

    final rows = <ChildReportAttendanceRow>[];
    for (final raw in (data as List)) {
      final map = raw as Map<String, dynamic>;
      final sw = map['scheduled_workshops'];
      final swMap =
          sw is Map ? sw.cast<String, dynamic>() : <String, dynamic>{};
      final status = (map['status'] as String?) ?? '';
      if (status.isEmpty) continue;
      rows.add(ChildReportAttendanceRow(
        date: _parseDate(swMap['workshop_date']),
        workshopTitle: (swMap['title'] as String?) ?? 'Atelier',
        workshopType: swMap['workshop_type'] as String?,
        trainerName: _trainerNameFrom(swMap['profiles']),
        startTime: swMap['start_time'] as String?,
        endTime: swMap['end_time'] as String?,
        status: status,
        observation: (map['observation'] as String?)?.trim().isEmpty == true
            ? null
            : map['observation'] as String?,
      ));
    }

    // Newest first: by workshop_date desc, then start_time desc.
    rows.sort((a, b) {
      final dateCmp = (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0));
      if (dateCmp != 0) return dateCmp;
      return (b.startTime ?? '').compareTo(a.startTime ?? '');
    });
    return rows;
  }

  // ── Afterschool queries ───────────────────────────────────────────────────

  Future<AfterschoolEnrollmentBundle> _fetchAfterschoolEnrollments(
      String childId) async {
    final data = await _client
        .from('afterschool_enrollments')
        .select('''
          id, child_id, program_id, enrolled_from, enrolled_until,
          attendance_days, expected_arrival_time, is_active,
          notes, enrolled_by, created_at, updated_at,
          afterschool_programs!program_id(
            id, name, description, days_of_week,
            start_time, end_time, monthly_fee, currency, max_capacity,
            active_from, active_to, is_active, archived_at,
            archived_by, archived_reason, notes, created_at, updated_at
          )
        ''')
        .eq('child_id', childId);

    final enrollments = <AfterschoolEnrollment>[];
    final programsById = <String, AfterschoolProgram>{};
    for (final raw in (data as List)) {
      final m = raw as Map<String, dynamic>;
      final progMap = m['afterschool_programs'];
      if (progMap is! Map) continue;
      try {
        final enr = AfterschoolEnrollment.fromMap(m);
        final prog = AfterschoolProgram.fromMap(
            progMap.cast<String, dynamic>());
        enrollments.add(enr);
        programsById[prog.id] = prog;
      } catch (_) {
        // Defensive — skip malformed row rather than aborting the report.
        continue;
      }
    }
    return AfterschoolEnrollmentBundle(
      enrollments: enrollments,
      programsById: programsById,
    );
  }

  Future<List<AfterschoolSession>> _fetchAfterschoolSessions(
      List<String> programIds) async {
    if (programIds.isEmpty) return const [];
    final data = await _client
        .from('afterschool_sessions')
        .select('''
          id, program_id, session_date, start_time, end_time,
          variant, is_closed, closed_reason, closed_by, closed_at, created_at
        ''')
        .inFilter('program_id', programIds);
    return (data as List)
        .map((r) => AfterschoolSession.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<AfterschoolAttendance>> _fetchAfterschoolAttendance(
      String childId) async {
    final data = await _client
        .from('afterschool_attendance')
        .select('''
          id, session_id, child_id, status, observation,
          marked_at, marked_by, updated_at
        ''')
        .eq('child_id', childId);
    return (data as List)
        .map((r) => AfterschoolAttendance.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<ChildReportPaymentRow>> _fetchPaymentCycles(
      String childId) async {
    final data = await _client
        .from('payment_cycles')
        .select(
            'period_start, period_end, sessions_count, status, '
            'payment_method, paid_at, notes, created_at, '
            'workshop_series!series_id(title)')
        .eq('child_id', childId);

    final rows = (data as List).map((raw) {
      final map = raw as Map<String, dynamic>;
      final ws = map['workshop_series'] as Map<String, dynamic>?;
      return ChildReportPaymentRow(
        periodStart: _parseDate(map['period_start']),
        periodEnd: _parseDate(map['period_end']),
        sessionsCount: (map['sessions_count'] as num?)?.toInt(),
        status: map['status'] as String?,
        paymentMethod: map['payment_method'] as String?,
        paidAt: _parseDateTime(map['paid_at']),
        notes: (map['notes'] as String?)?.trim().isEmpty == true
            ? null
            : map['notes'] as String?,
        seriesTitle: ws?['title'] as String?,
      );
    }).toList();

    // Newest first: prefer period_start when present, fall back to paid_at.
    rows.sort((a, b) {
      final aKey = a.periodStart ?? a.paidAt ?? DateTime(0);
      final bKey = b.periodStart ?? b.paidAt ?? DateTime(0);
      return bKey.compareTo(aKey);
    });
    return rows;
  }

  // ── Assembly helpers ──────────────────────────────────────────────────────

  ChildReportChildInfo _childInfoFromRow(Map<String, dynamic> row) {
    final birth = _parseDate(row['birth_date']);
    final firstName = (row['first_name'] as String?) ?? '';
    final lastName = (row['last_name'] as String?) ?? '';
    final fullName = '$firstName $lastName'.trim();
    return ChildReportChildInfo(
      id: row['id'] as String,
      fullName: fullName.isEmpty ? '—' : fullName,
      birthDate: birth,
      age: birth != null ? _yearsBetween(birth, DateTime.now()) : null,
      parentName: (row['parent_name'] as String?)?.trim().isEmpty == true
          ? null
          : row['parent_name'] as String?,
      parentPhone: (row['parent_phone'] as String?)?.trim().isEmpty == true
          ? null
          : row['parent_phone'] as String?,
      parentEmail: null,
    );
  }

  ChildReportWorkshopInfo _workshopInfoFromMap(Map<String, dynamic> map) {
    return ChildReportWorkshopInfo(
      title: (map['title'] as String?) ?? '—',
      workshopType: map['workshop_type'] as String?,
      dayOfWeek: map['day_of_week'] as String?,
      startTime: map['start_time'] as String?,
      endTime: map['end_time'] as String?,
      trainerName: _trainerNameFrom(map['profiles']),
    );
  }

  String? _trainerNameFrom(dynamic raw) {
    if (raw is! Map) return null;
    final fn = (raw['first_name'] as String?) ?? '';
    final ln = (raw['last_name'] as String?) ?? '';
    final full = '$fn $ln'.trim();
    return full.isEmpty ? null : full;
  }

  // ── Afterschool build helpers live as top-level pure functions
  //    below so tests can exercise them without a Supabase client.
  //    See `assembleChildActivityReport`. ─────────────────────────────────

  /// Compact Romanian label for an ISO-weekday set: "L-V" for a
  /// contiguous Monday-Friday, "L, Mi, V" otherwise.
  static String _romanianIsoWeekdayLabel(Set<int> daysIso) {
    if (daysIso.isEmpty) return '—';
    final sorted = daysIso.toList()..sort();
    const letters = ['L', 'Ma', 'Mi', 'J', 'V', 'S', 'D'];
    // Collapse contiguous runs with length ≥ 3 into "First-Last".
    final parts = <String>[];
    var i = 0;
    while (i < sorted.length) {
      var j = i;
      while (j + 1 < sorted.length && sorted[j + 1] == sorted[j] + 1) {
        j++;
      }
      final runLen = j - i + 1;
      if (runLen >= 3) {
        parts.add('${letters[sorted[i] - 1]}-${letters[sorted[j] - 1]}');
      } else {
        for (var k = i; k <= j; k++) {
          parts.add(letters[sorted[k] - 1]);
        }
      }
      i = j + 1;
    }
    return parts.join(', ');
  }

  // ── Parsing helpers ───────────────────────────────────────────────────────

  DateTime? _parseDate(dynamic raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  DateTime? _parseDateTime(dynamic raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  int _yearsBetween(DateTime from, DateTime to) {
    var years = to.year - from.year;
    if (to.month < from.month ||
        (to.month == from.month && to.day < from.day)) {
      years--;
    }
    return years;
  }
}

/// Return value of the first-stage Afterschool query — enrollment
/// rows + their program metadata. Sessions / attendance come in a
/// second stage, keyed off the resolved program ids.
@visibleForTesting
class AfterschoolEnrollmentBundle {
  const AfterschoolEnrollmentBundle({
    required this.enrollments,
    required this.programsById,
  });
  final List<AfterschoolEnrollment> enrollments;
  final Map<String, AfterschoolProgram> programsById;
}

/// Combined Afterschool working set used by the pure assembly layer.
/// `@visibleForTesting` so test code can construct one with hand-
/// crafted in-memory inputs without going through Supabase.
@visibleForTesting
class AfterschoolBundle {
  const AfterschoolBundle({
    required this.enrollments,
    required this.programsById,
    required this.sessions,
    required this.attendance,
  });
  factory AfterschoolBundle.empty() => const AfterschoolBundle(
        enrollments: [],
        programsById: {},
        sessions: [],
        attendance: [],
      );
  final List<AfterschoolEnrollment> enrollments;
  final Map<String, AfterschoolProgram> programsById;
  final List<AfterschoolSession> sessions;
  final List<AfterschoolAttendance> attendance;
}

/// Pure assembly of [ChildActivityReportData] from pre-loaded parts.
/// Lets us test every semantic (merged history ordering, future-day
/// handling, Afterschool-payments exclusion, workshop-payments
/// preservation) without touching Supabase.
///
/// `fetchChildActivityReport` runs the queries, then delegates to
/// this factory. The call sites — repository and tests — share one
/// code path.
@visibleForTesting
ChildActivityReportData assembleChildActivityReport({
  required ChildReportChildInfo childInfo,
  required List<ChildReportWorkshopInfo> activeWorkshops,
  required List<ChildReportAttendanceRow> workshopAttendance,
  required List<ChildReportPaymentRow> payments,
  required AfterschoolBundle afsBundle,
  required String childId,
  required DateTime today,
  required DateTime generatedAt,
}) {
  final activePrograms = _buildActiveAfterschoolPrograms(afsBundle, today);
  final afterschoolMonths =
      _buildAfterschoolMonths(childId: childId, bundle: afsBundle, today: today);
  final afterschoolHistoryRows = _buildAfterschoolHistoryRows(afsBundle);

  // Merge Workshop + Afterschool activity rows; sorted newest-first.
  final attendance = <ChildReportAttendanceRow>[
    ...workshopAttendance,
    ...afterschoolHistoryRows,
  ]..sort((a, b) {
      final da = a.date ?? DateTime(0);
      final db = b.date ?? DateTime(0);
      final cmp = db.compareTo(da);
      if (cmp != 0) return cmp;
      return (b.startTime ?? '').compareTo(a.startTime ?? '');
    });

  final observations = _buildObservations(attendance);
  final summary = buildReportSummary(
    workshopAttendance: workshopAttendance,
    payments: payments,
    afterschoolMonths: afterschoolMonths,
    afterschoolProgramsCount: afsBundle.programsById.length,
  );

  return ChildActivityReportData(
    childInfo: childInfo,
    activeWorkshops: activeWorkshops,
    activeAfterschoolPrograms: activePrograms,
    attendanceRows: attendance,
    afterschoolMonths: afterschoolMonths,
    paymentRows: payments,
    observations: observations,
    summary: summary,
    generatedAt: generatedAt,
  );
}

List<ChildReportAfterschoolProgramInfo> _buildActiveAfterschoolPrograms(
    AfterschoolBundle bundle, DateTime today) {
  final seen = <String>{};
  final list = <ChildReportAfterschoolProgramInfo>[];
  for (final e in bundle.enrollments) {
    if (!e.isActive) continue;
    if (!e.coversDate(today)) continue;
    if (!seen.add(e.programId)) continue;
    final prog = bundle.programsById[e.programId];
    if (prog == null) continue;
    list.add(ChildReportAfterschoolProgramInfo(
      programName: prog.name,
      daysOfWeekLabel:
          ChildReportRepository._romanianIsoWeekdayLabel(prog.daysOfWeek),
      startTime: prog.startTimeShort,
      endTime: prog.endTimeShort,
    ));
  }
  list.sort((a, b) => a.programName.compareTo(b.programName));
  return list;
}

List<ChildReportAfterschoolMonth> _buildAfterschoolMonths({
  required String childId,
  required AfterschoolBundle bundle,
  required DateTime today,
}) {
  final todayDate = DateTime(today.year, today.month, today.day);
  final result = <ChildReportAfterschoolMonth>[];

  final byProgram = <String, List<AfterschoolEnrollment>>{};
  for (final e in bundle.enrollments) {
    byProgram.putIfAbsent(e.programId, () => []).add(e);
  }

  for (final entry in byProgram.entries) {
    final programId = entry.key;
    final enrs = entry.value;
    final prog = bundle.programsById[programId];
    if (prog == null) continue;

    DateTime start = enrs.first.enrolledFrom;
    DateTime? latestEnd;
    for (final e in enrs) {
      if (e.enrolledFrom.isBefore(start)) start = e.enrolledFrom;
      final u = e.enrolledUntil;
      if (u != null && (latestEnd == null || u.isAfter(latestEnd))) {
        latestEnd = u;
      }
    }
    final tail = latestEnd == null || latestEnd.isAfter(todayDate)
        ? todayDate
        : latestEnd;

    var cursor = DateTime(start.year, start.month, 1);
    final end = DateTime(tail.year, tail.month, 1);
    while (!cursor.isAfter(end)) {
      final y = cursor.year;
      final m = cursor.month;
      final sessionsInMonth = bundle.sessions
          .where((s) =>
              s.programId == programId &&
              s.sessionDate.year == y &&
              s.sessionDate.month == m)
          .toList();
      final sessionIds = sessionsInMonth.map((s) => s.id).toSet();
      final attInMonth = bundle.attendance
          .where((a) => sessionIds.contains(a.sessionId))
          .toList();

      final snap = computeAfterschoolMonthAttendance(
        childId: childId,
        program: prog,
        year: y,
        month: m,
        enrollments: enrs,
        sessionsInMonth: sessionsInMonth,
        attendance: attInMonth,
        today: todayDate,
      );

      if (snap.expected > 0 ||
          snap.plannedFuture > 0 ||
          snap.unexpected > 0) {
        result.add(ChildReportAfterschoolMonth(
          programId: programId,
          programName: prog.name,
          year: y,
          month: m,
          expected: snap.expected,
          present: snap.present,
          absent: snap.absent,
          unmarked: snap.unmarked,
          plannedFuture: snap.plannedFuture,
          lastPresenceDate: snap.lastPresenceDate,
        ));
      }
      cursor = DateTime(y, m + 1, 1);
    }
  }

  result.sort((a, b) {
    final da = DateTime(a.year, a.month, 1);
    final db = DateTime(b.year, b.month, 1);
    final cmp = db.compareTo(da);
    if (cmp != 0) return cmp;
    return a.programName.compareTo(b.programName);
  });
  return result;
}

List<ChildReportAttendanceRow> _buildAfterschoolHistoryRows(
    AfterschoolBundle bundle) {
  final sessionById = {for (final s in bundle.sessions) s.id: s};
  final list = <ChildReportAttendanceRow>[];
  for (final att in bundle.attendance) {
    final session = sessionById[att.sessionId];
    if (session == null) continue;
    final prog = bundle.programsById[session.programId];
    if (prog == null) continue;
    list.add(ChildReportAttendanceRow(
      date: session.sessionDate,
      workshopTitle: prog.name,
      workshopType: 'Afterschool',
      trainerName: null,
      startTime: prog.startTimeShort,
      endTime: prog.endTimeShort,
      status: att.status.toDb(),
      observation: (att.observation == null ||
              att.observation!.trim().isEmpty)
          ? null
          : att.observation,
    ));
  }
  return list;
}

List<ChildReportObservation> _buildObservations(
    List<ChildReportAttendanceRow> attendance) {
  final result = <ChildReportObservation>[];
  for (final row in attendance) {
    final obs = row.observation;
    if (obs == null || obs.trim().isEmpty) continue;
    result.add(ChildReportObservation(
      date: row.date,
      workshopTitle: row.workshopTitle,
      text: obs.trim(),
    ));
  }
  return result;
}

@visibleForTesting
ChildReportSummary buildReportSummary({
  required List<ChildReportAttendanceRow> workshopAttendance,
  required List<ChildReportPaymentRow> payments,
  required List<ChildReportAfterschoolMonth> afterschoolMonths,
  required int afterschoolProgramsCount,
}) {
  var present = 0;
  var absent = 0;
  var motivated = 0;
  final titles = <String>{};
  for (final row in workshopAttendance) {
    switch (row.status) {
      case 'present':
        present++;
        break;
      case 'absent':
        absent++;
        break;
      case 'motivated':
        motivated++;
        break;
    }
    titles.add(row.workshopTitle);
  }
  final total = present + absent + motivated;
  final rate = total == 0 ? 0.0 : present / total;

  var confirmed = 0;
  var overdue = 0;
  for (final p in payments) {
    switch (p.status) {
      case 'paid':
      case 'paid_advance':
        confirmed++;
        break;
      case 'overdue':
        overdue++;
        break;
    }
  }

  var afsPresent = 0;
  var afsAbsent = 0;
  var afsUnmarked = 0;
  var afsPlanned = 0;
  DateTime? afsLast;
  for (final m in afterschoolMonths) {
    afsPresent += m.present;
    afsAbsent += m.absent;
    afsUnmarked += m.unmarked;
    afsPlanned += m.plannedFuture;
    final last = m.lastPresenceDate;
    if (last != null && (afsLast == null || last.isAfter(afsLast))) {
      afsLast = last;
    }
  }

  return ChildReportSummary(
    totalSessions: total,
    presentCount: present,
    absentCount: absent,
    motivatedCount: motivated,
    attendanceRate: rate,
    totalWorkshops: titles.length,
    totalPaymentCycles: payments.length,
    confirmedPayments: confirmed,
    overduePayments: overdue,
    afterschoolPresentCount: afsPresent,
    afterschoolAbsentCount: afsAbsent,
    afterschoolUnmarkedCount: afsUnmarked,
    afterschoolPlannedCount: afsPlanned,
    afterschoolProgramsCount: afterschoolProgramsCount,
    afterschoolLastPresenceDate: afsLast,
  );
}
