import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/child_calendar_session.dart';

/// Repository for the child-scoped historical attendance calendar.
///
/// Composes `attendance` + `scheduled_workshops` into per-day sessions and
/// wraps the same UPSERT contract that `WorkshopsRepository.markAttendance`
/// uses. Since the migration `20260817_chronological_payment_cycles.sql`,
/// every INSERT/UPDATE/DELETE on `attendance` triggers a per-child
/// chronological recalc of payment cycles, so historical edits never
/// corrupt cycle counts anymore. No client-side lock is needed.
class AttendanceCalendarRepository {
  const AttendanceCalendarRepository(this._client);

  final SupabaseClient _client;

  /// Fetches every eligible session for [childId] whose `workshop_date` is
  /// in the half-open range `[monthStart, monthEndExclusive)`.
  ///
  /// A session is "eligible" when either:
  ///   • the child already has an `attendance` row for the pair (persisted
  ///     history — always shown, even after unenroll or workshop archive),
  ///     OR
  ///   • the child is currently enrolled in the workshop's series AND the
  ///     workshop is active + not archived (recovery of a forgotten mark).
  Future<List<ChildCalendarSession>> fetchMonth({
    required String childId,
    required DateTime monthStart,
    required DateTime monthEndExclusive,
  }) async {
    final startStr = _dateOnly(monthStart);
    final endStr = _dateOnly(monthEndExclusive);

    // Step 1: full attendance history for the child, filtered locally
    //         to the requested date range.
    final attRowsRaw = await _client
        .from('attendance')
        .select(
          'id, child_id, scheduled_workshop_id, status, observation, '
          'marked_at, marked_by, '
          'scheduled_workshops!scheduled_workshop_id('
          '  id, title, workshop_type, workshop_date, day_of_week, '
          '  start_time, end_time, trainer_id, is_active, archived_at'
          '), '
          'profiles!marked_by(first_name, last_name)',
        )
        .eq('child_id', childId)
        .eq('is_archived', false);

    final attendanceSessions = <String, ChildCalendarSession>{};
    for (final row in (attRowsRaw as List)) {
      final map = row as Map<String, dynamic>;
      final ws = map['scheduled_workshops'] as Map<String, dynamic>?;
      if (ws == null) continue;
      final dateStr = ws['workshop_date'] as String?;
      if (dateStr == null) continue;
      if (dateStr.compareTo(startStr) < 0) continue;
      if (dateStr.compareTo(endStr) >= 0) continue;
      final wsId = ws['id'] as String;
      attendanceSessions[wsId] = _sessionFromAttendanceRow(map, ws);
    }

    // Step 2: active-enrolment scheduled_workshops in the same range
    //         that don't already appear above.
    final seriesIds = await _fetchActiveSeriesIds(childId);
    List<Map<String, dynamic>> unmarkedWs = const [];
    if (seriesIds.isNotEmpty) {
      final quoted = seriesIds.map((s) => '"$s"').join(',');
      final rows = await _client
          .from('scheduled_workshops')
          .select(
            'id, title, workshop_type, workshop_date, day_of_week, '
            'start_time, end_time, trainer_id, is_active, archived_at',
          )
          .gte('workshop_date', startStr)
          .lt('workshop_date', endStr)
          .eq('is_active', true)
          .filter('archived_at', 'is', null)
          .or('series_id.in.($quoted),recurring_series_id.in.($quoted)');
      unmarkedWs = (rows as List).cast<Map<String, dynamic>>();
    }

    final merged = <String, ChildCalendarSession>{...attendanceSessions};
    for (final ws in unmarkedWs) {
      final wsId = ws['id'] as String;
      if (merged.containsKey(wsId)) continue;
      merged[wsId] = _sessionFromWorkshopRow(ws, enrolmentActive: true);
    }

    // Step 3: afterschool. A child who only attends afterschool had an
    // empty workshop-only calendar before — every day cell rendered as
    // `onTap: null` → "all greyed out" bug. Historical correctness
    // mirrors the fix in `AfterschoolEnrollmentsRepository.fetchCoveringDate`:
    // use the enrollment date interval, NOT `is_active`.
    final afsEnrolments = await _client
        .from('afterschool_enrollments')
        .select('program_id, enrolled_from, enrolled_until, '
            'afterschool_programs!program_id(id, name)')
        .eq('child_id', childId)
        .lte('enrolled_from', endStr)
        .or('enrolled_until.is.null,enrolled_until.gte.$startStr');

    final afsProgramNames = <String, String>{};
    final afsProgramIdsInWindow = <String>{};
    for (final row in (afsEnrolments as List)) {
      final map = row as Map<String, dynamic>;
      final programId = map['program_id'] as String?;
      if (programId == null) continue;
      afsProgramIdsInWindow.add(programId);
      final prog = map['afterschool_programs'] as Map<String, dynamic>?;
      final name = prog?['name'] as String?;
      if (name != null && name.isNotEmpty) {
        afsProgramNames[programId] = name;
      }
    }

    if (afsProgramIdsInWindow.isNotEmpty) {
      // Materialise any missing afterschool_sessions rows in
      // [startStr, endStr) for each program the child was enrolled in
      // during the window. Idempotent server-side.
      for (final programId in afsProgramIdsInWindow) {
        try {
          await _client.rpc(
            'generate_afterschool_sessions_window',
            params: {
              'p_program_id': programId,
              'p_from': startStr,
              'p_to': endStr,
            },
          );
        } catch (_) {
          // Non-fatal: parent tokens lack execute grant; or the program's
          // active window doesn't cover the month. The SELECT below
          // still returns whatever is already materialised.
        }
      }

      final afsSessionsRaw = await _client
          .from('afterschool_sessions')
          .select('id, program_id, session_date, status, '
              'afterschool_programs!program_id(name, start_time, end_time)')
          .inFilter('program_id', afsProgramIdsInWindow.toList())
          .gte('session_date', startStr)
          .lt('session_date', endStr);
      final afsSessions =
          (afsSessionsRaw as List).cast<Map<String, dynamic>>();

      Map<String, Map<String, dynamic>> afsAttByCompositeKey = const {};
      if (afsSessions.isNotEmpty) {
        final sessionIds =
            afsSessions.map((s) => s['id'] as String).toList();
        final afsAttRows = await _client
            .from('afterschool_attendance')
            .select('id, session_id, child_id, status, observation, '
                'marked_at, marked_by, '
                'profiles!marked_by(first_name, last_name)')
            .eq('child_id', childId)
            .inFilter('session_id', sessionIds);
        afsAttByCompositeKey = {
          for (final r in (afsAttRows as List))
            (r as Map<String, dynamic>)['session_id'] as String: r,
        };
      }

      for (final sess in afsSessions) {
        final sessionId = sess['id'] as String;
        final programId = sess['program_id'] as String;
        final programBlock =
            sess['afterschool_programs'] as Map<String, dynamic>?;
        final att = afsAttByCompositeKey[sessionId];
        final dedupKey = 'afs:$sessionId';
        if (merged.containsKey(dedupKey)) continue;
        merged[dedupKey] = _sessionFromAfterschool(
          sessionRow: sess,
          programBlock: programBlock,
          programName: afsProgramNames[programId],
          attendanceRow: att,
        );
      }
    }

    final list = merged.values.toList();
    list.sort(_compareByDateAndTime);
    return list;
  }

  /// Builds a [ChildCalendarSession] from an afterschool session row
  /// (optional attendance row). The dedup key for the surrounding map
  /// is `'afs:<sessionId>'` so afterschool entries never collide with
  /// workshop ones.
  ChildCalendarSession _sessionFromAfterschool({
    required Map<String, dynamic> sessionRow,
    required Map<String, dynamic>? programBlock,
    required String? programName,
    required Map<String, dynamic>? attendanceRow,
  }) {
    final sessionId = sessionRow['id'] as String;
    final programId = sessionRow['program_id'] as String;
    final dateStr = sessionRow['session_date'] as String;
    final date = DateTime.parse(dateStr);
    final title = programName ??
        (programBlock?['name'] as String?) ??
        'Afterschool';
    final startTime = (programBlock?['start_time'] as String?) ?? '';
    final endTime = (programBlock?['end_time'] as String?) ?? '';

    String? markedByName;
    DateTime? markedAt;
    String? status;
    String? observation;
    String? attendanceId;
    if (attendanceRow != null) {
      attendanceId = attendanceRow['id'] as String?;
      status = attendanceRow['status'] as String?;
      observation = attendanceRow['observation'] as String?;
      final markedAtRaw = attendanceRow['marked_at'] as String?;
      if (markedAtRaw != null) markedAt = DateTime.parse(markedAtRaw);
      final profile =
          attendanceRow['profiles'] as Map<String, dynamic>?;
      if (profile != null) {
        final combined =
            '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}'
                .trim();
        if (combined.isNotEmpty) markedByName = combined;
      }
    }

    return ChildCalendarSession(
      // Synthetic composite id — the UI uses it only as a map key; the
      // real write target is [afterschoolSessionId].
      scheduledWorkshopId: 'afs:$sessionId',
      workshopDate: DateTime(date.year, date.month, date.day),
      startTime: startTime,
      endTime: endTime,
      workshopTitle: title,
      workshopType: 'Afterschool',
      dayOfWeek: null,
      trainerId: null,
      attendanceId: attendanceId,
      status: status,
      observation: observation,
      markedAt: markedAt,
      markedByName: markedByName,
      isEnrolmentActive: true,
      kind: ChildCalendarSessionKind.afterschool,
      afterschoolSessionId: sessionId,
      afterschoolProgramId: programId,
    );
  }

  /// UPSERTs an afterschool attendance row for `(childId, sessionId)`.
  /// Server-side check constraint only allows `'present'` / `'absent'`.
  Future<void> upsertAfterschoolAttendance({
    required String childId,
    required String afterschoolSessionId,
    required String status,
    String? observation,
    required String markedBy,
    required bool isStaff,
  }) async {
    if (!isStaff) throw StateError('Unauthorized role');
    if (status != 'present' && status != 'absent') {
      throw ArgumentError.value(status, 'status');
    }
    await _client.from('afterschool_attendance').upsert({
      'session_id': afterschoolSessionId,
      'child_id': childId,
      'status': status,
      'observation': observation,
      'marked_by': markedBy,
      'marked_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'session_id,child_id');
  }

  /// Removes an afterschool attendance row entirely. Admin-only (RLS
  /// also enforces this per `20261001_afterschool_attendance_delete_staff.sql`).
  Future<void> deleteAfterschoolAttendance({
    required String attendanceId,
    required bool isStaff,
  }) async {
    if (!isStaff) {
      throw StateError('Only staff may delete attendance rows');
    }
    await _client.from('afterschool_attendance').delete().eq('id', attendanceId);
  }

  /// Past sessions in the last [monthsBack] months for [childId] that have
  /// no attendance recorded. Used by the "Prezențe necompletate" mode.
  Future<List<ChildCalendarSession>> fetchMissing({
    required String childId,
    int monthsBack = 6,
    int limit = 200,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final from = DateTime(now.year, now.month - monthsBack, 1);

    final seriesIds = await _fetchActiveSeriesIds(childId);
    if (seriesIds.isEmpty) return const [];

    final quoted = seriesIds.map((s) => '"$s"').join(',');
    final wsRows = await _client
        .from('scheduled_workshops')
        .select(
          'id, title, workshop_type, workshop_date, day_of_week, '
          'start_time, end_time, trainer_id, is_active, archived_at',
        )
        .gte('workshop_date', _dateOnly(from))
        .lte('workshop_date', _dateOnly(today))
        .eq('is_active', true)
        .filter('archived_at', 'is', null)
        .or('series_id.in.($quoted),recurring_series_id.in.($quoted)')
        .order('workshop_date', ascending: false);

    final wsList = (wsRows as List).cast<Map<String, dynamic>>();
    if (wsList.isEmpty) return const [];

    final wsIds = wsList.map((w) => w['id'] as String).toList();
    final existing = await _client
        .from('attendance')
        .select('scheduled_workshop_id')
        .eq('child_id', childId)
        .inFilter('scheduled_workshop_id', wsIds);
    final markedIds = <String>{
      for (final r in (existing as List))
        (r as Map<String, dynamic>)['scheduled_workshop_id'] as String,
    };

    final out = <ChildCalendarSession>[];
    for (final ws in wsList) {
      final wsId = ws['id'] as String;
      if (markedIds.contains(wsId)) continue;
      out.add(_sessionFromWorkshopRow(ws, enrolmentActive: true));
      if (out.length >= limit) break;
    }
    return out;
  }

  /// Ensures every recurring series the child is currently enrolled in
  /// has all its weekly `scheduled_workshops` rows materialised from
  /// `workshop_series.start_date` to today. Called by the calendar
  /// modal once per open so historical dates the legacy generator never
  /// filled become selectable.
  ///
  /// Delegates to the `ensure_child_series_backfilled` RPC — idempotent,
  /// cheap (skips existing rows). Returns the total number of new
  /// `scheduled_workshops` rows inserted (usually 0).
  Future<int> ensureBackfilled(String childId) async {
    final res = await _client
        .rpc('ensure_child_series_backfilled', params: {
      'p_child_id': childId,
    });
    if (res is Map && res['total_inserted'] is int) {
      return res['total_inserted'] as int;
    }
    if (res is Map && res['total_inserted'] is num) {
      return (res['total_inserted'] as num).toInt();
    }
    return 0;
  }

  /// Sets attendance for `(childId, scheduledWorkshopId)`, creating a new
  /// row on first touch or updating the existing one otherwise.
  ///
  /// Same UPSERT contract as `WorkshopsRepository.markAttendance`. The
  /// server-side trigger `trg_recalculate_cycles_on_attendance` recomputes
  /// the child's payment cycles chronologically after the write, so
  /// historical edits are always safe.
  Future<void> upsertAttendance({
    required String childId,
    required String scheduledWorkshopId,
    required String status,
    String? observation,
    required String markedBy,
    required bool isStaff,
  }) async {
    if (!isStaff) {
      throw StateError('Unauthorized role');
    }
    if (status != 'present' && status != 'absent' && status != 'motivated') {
      throw ArgumentError.value(status, 'status');
    }

    await _client.from('attendance').upsert(
      {
        'scheduled_workshop_id': scheduledWorkshopId,
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

  /// Removes an `attendance` row entirely. Use ONLY for rows that were
  /// created by mistake (wrong child, wrong session — not a "child was
  /// absent" case, which should be recorded as `absent` instead).
  ///
  /// Staff-only guarded here (client defence). Since migration
  /// `20260823_attendance_delete_trainer.sql`, the server-side policy
  /// `attendance_delete_admin_or_trainer` allows either an admin OR a
  /// trainer that owns the scheduled_workshop the attendance points to
  /// — so a trainer trying to delete for someone else's workshop still
  /// gets rejected at the DB level.
  ///
  /// The DB trigger `trg_recalculate_cycles_on_attendance` fires on
  /// DELETE and re-runs `recalculate_child_series_payment_cycles` for
  /// the affected (child, series), so payment cycles stay consistent
  /// automatically.
  Future<void> deleteAttendance({
    required String attendanceId,
    required bool isStaff,
  }) async {
    if (!isStaff) {
      throw StateError('Only staff may delete attendance rows');
    }
    await _client.from('attendance').delete().eq('id', attendanceId);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  Future<List<String>> _fetchActiveSeriesIds(String childId) async {
    final rows = await _client
        .from('workshop_enrollments')
        .select('series_id')
        .eq('child_id', childId)
        .eq('is_active', true);
    return (rows as List)
        .map((r) => (r as Map<String, dynamic>)['series_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
  }

  static String _dateOnly(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static int _compareByDateAndTime(
      ChildCalendarSession a, ChildCalendarSession b) {
    final c = a.workshopDate.compareTo(b.workshopDate);
    if (c != 0) return c;
    return a.startTime.compareTo(b.startTime);
  }

  ChildCalendarSession _sessionFromAttendanceRow(
    Map<String, dynamic> row,
    Map<String, dynamic> ws,
  ) {
    final profile = row['profiles'] as Map<String, dynamic>?;
    final markedByName = profile == null
        ? null
        : '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}'
            .trim();

    final workshopDate = DateTime.parse(ws['workshop_date'] as String);
    return ChildCalendarSession(
      scheduledWorkshopId: ws['id'] as String,
      workshopDate:
          DateTime(workshopDate.year, workshopDate.month, workshopDate.day),
      startTime: (ws['start_time'] as String?) ?? '',
      endTime: (ws['end_time'] as String?) ?? '',
      workshopTitle: (ws['title'] as String?) ?? '',
      workshopType: (ws['workshop_type'] as String?) ?? '',
      dayOfWeek: ws['day_of_week'] as String?,
      trainerId: ws['trainer_id'] as String?,
      attendanceId: row['id'] as String?,
      status: row['status'] as String?,
      observation: row['observation'] as String?,
      markedAt: (row['marked_at'] as String?) != null
          ? DateTime.parse(row['marked_at'] as String)
          : null,
      markedByName: (markedByName == null || markedByName.isEmpty)
          ? null
          : markedByName,
      isWorkshopArchived: ws['archived_at'] != null ||
          (ws['is_active'] as bool? ?? true) == false,
    );
  }

  ChildCalendarSession _sessionFromWorkshopRow(
    Map<String, dynamic> ws, {
    required bool enrolmentActive,
  }) {
    final workshopDate = DateTime.parse(ws['workshop_date'] as String);
    return ChildCalendarSession(
      scheduledWorkshopId: ws['id'] as String,
      workshopDate:
          DateTime(workshopDate.year, workshopDate.month, workshopDate.day),
      startTime: (ws['start_time'] as String?) ?? '',
      endTime: (ws['end_time'] as String?) ?? '',
      workshopTitle: (ws['title'] as String?) ?? '',
      workshopType: (ws['workshop_type'] as String?) ?? '',
      dayOfWeek: ws['day_of_week'] as String?,
      trainerId: ws['trainer_id'] as String?,
      isWorkshopArchived: ws['archived_at'] != null ||
          (ws['is_active'] as bool? ?? true) == false,
      isEnrolmentActive: enrolmentActive,
    );
  }
}
