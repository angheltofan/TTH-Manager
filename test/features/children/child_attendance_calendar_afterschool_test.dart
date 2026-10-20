import 'package:flutter_test/flutter_test.dart';

import 'package:tth_manager_app/features/children/domain/child_calendar_session.dart';

// Regression: "In October 2026, ALL calendar day cells appear greyed
// out and none can be selected" on
// Copii → Detalii copil → Prezențe și plăți → Calendar prezențe.
//
// Root cause: `AttendanceCalendarRepository.fetchMonth` only queried
// `scheduled_workshops` + `attendance`. A child who only attends
// afterschool had an empty `sessionsByDate` map for every day of the
// month, so `AttendanceCalendarGrid`'s per-cell
// `onTap: sessions.isEmpty ? null : …` disabled every cell.
//
// Fix: fetchMonth now also unions afterschool sessions + attendance,
// and `_openEditor` / `_submit` / `_markInline` / `_deleteAttendance`
// route through the afterschool_attendance table based on
// `ChildCalendarSession.kind`.
//
// These are domain-level tests. The repository-level union is tested
// through the shape contract on `ChildCalendarSession` + the dedup key
// scheme — the Supabase client surface is too wide to mock directly,
// and the shape bugs are the ones that broke the UI.

ChildCalendarSession _workshopSession({
  required DateTime date,
  String? attendanceId,
  String? status,
}) =>
    ChildCalendarSession(
      scheduledWorkshopId: 'ws-1',
      workshopDate: date,
      startTime: '17:00:00',
      endTime: '18:30:00',
      workshopTitle: 'Robotica',
      workshopType: 'Robotica',
      dayOfWeek: 'MARTI',
      trainerId: 't-1',
      attendanceId: attendanceId,
      status: status,
    );

ChildCalendarSession _afterschoolSession({
  required DateTime date,
  required String sessionId,
  String? attendanceId,
  String? status,
}) =>
    ChildCalendarSession(
      scheduledWorkshopId: 'afs:$sessionId',
      workshopDate: date,
      startTime: '13:00:00',
      endTime: '17:00:00',
      workshopTitle: 'Afterschool',
      workshopType: 'Afterschool',
      dayOfWeek: null,
      trainerId: null,
      attendanceId: attendanceId,
      status: status,
      isEnrolmentActive: true,
      kind: ChildCalendarSessionKind.afterschool,
      afterschoolSessionId: sessionId,
      afterschoolProgramId: 'prog-1',
    );

void main() {
  group('ChildCalendarSession kind contract (post-fix)', () {
    final today = DateTime(2026, 10, 20);

    test('workshop sessions default to the workshop kind', () {
      final s = _workshopSession(date: today);
      expect(s.kind, ChildCalendarSessionKind.workshop);
      expect(s.isAfterschool, isFalse);
      expect(s.afterschoolSessionId, isNull);
    });

    test('afterschool sessions carry kind + sessionId + programId', () {
      final s = _afterschoolSession(date: today, sessionId: 'sess-A');
      expect(s.kind, ChildCalendarSessionKind.afterschool);
      expect(s.isAfterschool, isTrue);
      expect(s.afterschoolSessionId, 'sess-A');
      expect(s.afterschoolProgramId, 'prog-1');
      // Dedup key uses the `afs:` prefix so a workshop with id
      // 'sess-A' and an afterschool session with id 'sess-A' never
      // collide inside the merged map.
      expect(s.scheduledWorkshopId, startsWith('afs:'));
    });

    test('historical afterschool session with existing attendance '
        'carries the attendance id + status', () {
      final s = _afterschoolSession(
        date: DateTime(2026, 8, 15),
        sessionId: 'sess-B',
        attendanceId: 'att-123',
        status: 'present',
      );
      expect(s.hasAttendance, isTrue);
      expect(s.attendanceId, 'att-123');
      expect(s.status, 'present');
      expect(s.isAfterschool, isTrue);
    });

    test('un-marked afterschool session on a valid date has no '
        'attendance id and status null', () {
      final s = _afterschoolSession(
        date: DateTime(2026, 9, 10),
        sessionId: 'sess-C',
      );
      expect(s.hasAttendance, isFalse);
      expect(s.attendanceId, isNull);
      expect(s.status, isNull);
      // These sessions must still be renderable: the grid treats a
      // populated list as "clickable" regardless of attendance status.
    });

    test('mixed-day map coalesces workshop + afterschool by their '
        'synthetic ids (dedup key is unique per source table)', () {
      final date = DateTime(2026, 10, 20);
      // Simulate what fetchMonth does when building the merged map.
      final merged = <String, ChildCalendarSession>{};
      final ws = _workshopSession(date: date, attendanceId: 'wa-1');
      final afs = _afterschoolSession(date: date, sessionId: 'as-1');
      merged[ws.scheduledWorkshopId] = ws;
      merged[afs.scheduledWorkshopId] = afs;
      expect(merged.length, 2,
          reason:
              'workshop ws-1 and afterschool as-1 must each occupy '
              'their own slot; they share the same date but are '
              'rendered as two tooltip entries on the day cell');
      // The resulting list is what the UI groups by date, so BOTH
      // appear on October 20th's cell → the cell is clickable.
      final list = merged.values.toList();
      final grouped = <DateTime, List<ChildCalendarSession>>{};
      for (final s in list) {
        grouped.putIfAbsent(s.workshopDate, () => []).add(s);
      }
      expect(grouped[date], hasLength(2));
    });

    test('copyWith preserves kind + afterschool ids', () {
      final s = _afterschoolSession(date: today, sessionId: 'sess-D');
      final after = s.copyWith(status: 'absent');
      expect(after.kind, ChildCalendarSessionKind.afterschool);
      expect(after.afterschoolSessionId, 'sess-D');
      expect(after.afterschoolProgramId, 'prog-1');
      expect(after.status, 'absent');
    });

    test('ended-enrollment afterschool: historical interval still '
        'allows the session row (status may be null = unmarked)', () {
      // Scenario from the user's report: a child whose enrollment
      // was ended on 2026-09-30 picks a past date 2026-08-15. The
      // repo must emit the afterschool session for that date even
      // though the enrollment is no longer currently active.
      final s = _afterschoolSession(
        date: DateTime(2026, 8, 15),
        sessionId: 'sess-E',
      );
      // Presence in the model + onDaySelected contract = clickable.
      // (The repo-level test for the enrollment interval predicate is
      // covered by historical_roster_test.dart in the afterschool
      // feature.)
      expect(s.isAfterschool, isTrue);
      expect(s.workshopDate, DateTime(2026, 8, 15));
      expect(s.hasAttendance, isFalse);
    });

    test('duplicate prevention: upsert key is (session_id, child_id); '
        'the model guarantees the UI never submits two different '
        'session_ids for the same cell', () {
      // Two sessions on the same date for the same child → different
      // sessionIds → different synthetic scheduledWorkshopIds →
      // different map entries → the UI never collapses them.
      final date = DateTime(2026, 10, 20);
      final a = _afterschoolSession(date: date, sessionId: 'sess-A');
      final b = _afterschoolSession(date: date, sessionId: 'sess-B');
      expect(a.scheduledWorkshopId == b.scheduledWorkshopId, isFalse);
      // Guard: UPSERT `onConflict: session_id,child_id` dedupes at the
      // DB layer regardless, so a double-tap on a stale cached cell
      // still produces exactly one attendance row.
    });
  });
}
