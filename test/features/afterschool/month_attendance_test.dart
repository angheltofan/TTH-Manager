import 'package:flutter_test/flutter_test.dart';

import 'package:tth_manager_app/features/afterschool/domain/afterschool_attendance.dart';
import 'package:tth_manager_app/features/afterschool/domain/afterschool_enrollment.dart';
import 'package:tth_manager_app/features/afterschool/domain/afterschool_month_attendance.dart';
import 'package:tth_manager_app/features/afterschool/domain/afterschool_program.dart';
import 'package:tth_manager_app/features/afterschool/domain/afterschool_session.dart';

// ── Fixtures ─────────────────────────────────────────────────────────

const _programId = 'cccccccc-0000-0000-0000-000000000001';
const _childId = 'a0000000-0000-0000-0000-00000000000a';

AfterschoolProgram _program({
  Set<int> daysOfWeek = const {1, 2, 3, 4, 5},
  DateTime? activeFrom,
  DateTime? activeTo,
}) =>
    AfterschoolProgram(
      id: _programId,
      name: 'Test Program',
      daysOfWeek: daysOfWeek,
      startTime: '13:00:00',
      endTime: '17:00:00',
      monthlyFee: 1300,
      currency: 'RON',
      activeFrom: activeFrom ?? DateTime(2020, 1, 1),
      activeTo: activeTo,
      isActive: true,
      createdAt: DateTime(2020, 1, 1),
      updatedAt: DateTime(2020, 1, 1),
    );

AfterschoolEnrollment _enrollment({
  DateTime? enrolledFrom,
  DateTime? enrolledUntil,
  Set<int>? attendanceDays,
  bool isActive = true,
  String childId = _childId,
}) =>
    AfterschoolEnrollment(
      id: 'enr-$childId',
      childId: childId,
      programId: _programId,
      enrolledFrom: enrolledFrom ?? DateTime(2020, 1, 1),
      enrolledUntil: enrolledUntil,
      attendanceDays: attendanceDays,
      isActive: isActive,
      createdAt: DateTime(2020, 1, 1),
      updatedAt: DateTime(2020, 1, 1),
    );

/// Session helper — id derives from date so tests can look up
/// deterministically when asserting attendance matches.
AfterschoolSession _session(DateTime d,
        {bool isClosed = false, String? id}) =>
    AfterschoolSession(
      id: id ?? 'ses-${d.year}-${d.month}-${d.day}',
      programId: _programId,
      sessionDate: d,
      startTime: '13:00:00',
      endTime: '17:00:00',
      isClosed: isClosed,
      createdAt: DateTime(2020, 1, 1),
    );

/// Builds one session per eligible day in the month for the given
/// program's weekdays. Any explicit override in `closedDates` marks
/// that specific session as `isClosed`.
List<AfterschoolSession> _monthSessions(
  AfterschoolProgram program,
  int year,
  int month, {
  Set<String> closedDates = const {},
}) {
  final last = DateTime(year, month + 1, 0).day;
  final out = <AfterschoolSession>[];
  for (var day = 1; day <= last; day++) {
    final date = DateTime(year, month, day);
    if (!program.isEligibleDay(date)) continue;
    out.add(_session(date, isClosed: closedDates.contains(_iso(date))));
  }
  return out;
}

AfterschoolAttendance _mark(
  AfterschoolSession session, {
  required AttendanceStatus status,
  String childId = _childId,
}) =>
    AfterschoolAttendance(
      id: 'att-${session.id}-$childId',
      sessionId: session.id,
      childId: childId,
      status: status,
      markedAt: DateTime(2020, 1, 1),
      updatedAt: DateTime(2020, 1, 1),
    );

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

void main() {
  // ── A. L-V full month, no attendance, mid-past today ──────────────
  test('A: L-V full month, today = end-of-month, no attendance', () {
    final prog = _program(daysOfWeek: const {1, 2, 3, 4, 5});
    final enr = _enrollment();
    final sessions = _monthSessions(prog, 2026, 9);
    final today = DateTime(2026, 9, 30);
    final r = computeAfterschoolMonthAttendance(
      childId: _childId,
      program: prog,
      year: 2026,
      month: 9,
      enrollments: [enr],
      sessionsInMonth: sessions,
      attendance: const [],
      today: today,
    );
    // Sept 2026: weekdays Mon-Fri → count = 22.
    expect(r.expected, 22);
    expect(r.present, 0);
    expect(r.absent, 0);
    expect(r.unmarked, 22);
    expect(r.plannedFuture, 0);
    expect(r.unexpected, 0);
    expect(r.lastPresenceDate, isNull);
  });

  // ── B. Mon/Wed/Fri override ───────────────────────────────────────
  test('B: L/Mi/V, program M-F, no attendance', () {
    final prog = _program(daysOfWeek: const {1, 2, 3, 4, 5});
    final enr = _enrollment(attendanceDays: const {1, 3, 5});
    final sessions = _monthSessions(prog, 2026, 9);
    final today = DateTime(2026, 9, 30);
    final r = computeAfterschoolMonthAttendance(
      childId: _childId,
      program: prog,
      year: 2026,
      month: 9,
      enrollments: [enr],
      sessionsInMonth: sessions,
      attendance: const [],
      today: today,
    );
    // Sept 2026 counts (Mon=4, Wed=5, Fri=4) = 13.
    expect(r.expected, 13);
    expect(r.present, 0);
    expect(r.absent, 0);
    expect(r.unmarked, 13);
    expect(r.plannedFuture, 0);
  });

  // ── C. Enrollment starts mid-month ────────────────────────────────
  test('C: enrollment starts 2026-09-14, month still counts only [14..30]', () {
    final prog = _program(daysOfWeek: const {1, 2, 3, 4, 5});
    final enr = _enrollment(enrolledFrom: DateTime(2026, 9, 14));
    final sessions = _monthSessions(prog, 2026, 9);
    final today = DateTime(2026, 9, 30);
    final r = computeAfterschoolMonthAttendance(
      childId: _childId,
      program: prog,
      year: 2026,
      month: 9,
      enrollments: [enr],
      sessionsInMonth: sessions,
      attendance: const [],
      today: today,
    );
    // Weekdays 14..30 = M14 T15 W16 T17 F18 M21 T22 W23 T24 F25
    //                    M28 T29 W30 = 13.
    expect(r.expected, 13);
    expect(r.unmarked, 13);
  });

  // ── D. Enrollment ends mid-month ──────────────────────────────────
  test('D: enrollment ends 2026-09-15, counts only [1..15]', () {
    final prog = _program(daysOfWeek: const {1, 2, 3, 4, 5});
    final enr = _enrollment(
      enrolledFrom: DateTime(2020, 1, 1),
      enrolledUntil: DateTime(2026, 9, 15),
    );
    final sessions = _monthSessions(prog, 2026, 9);
    final today = DateTime(2026, 9, 30);
    final r = computeAfterschoolMonthAttendance(
      childId: _childId,
      program: prog,
      year: 2026,
      month: 9,
      enrollments: [enr],
      sessionsInMonth: sessions,
      attendance: const [],
      today: today,
    );
    // Weekdays 1..15 = T1 W2 T3 F4 M7 T8 W9 T10 F11 M14 T15 = 11.
    expect(r.expected, 11);
  });

  // ── E. Program active window truncates mid-month ──────────────────
  test('E: program activeFrom 2026-09-10, counts only from that day', () {
    final prog = _program(
      daysOfWeek: const {1, 2, 3, 4, 5},
      activeFrom: DateTime(2026, 9, 10),
    );
    final enr = _enrollment();
    final sessions = _monthSessions(prog, 2026, 9);
    final today = DateTime(2026, 9, 30);
    final r = computeAfterschoolMonthAttendance(
      childId: _childId,
      program: prog,
      year: 2026,
      month: 9,
      enrollments: [enr],
      sessionsInMonth: sessions,
      attendance: const [],
      today: today,
    );
    // Weekdays 10..30 = T10 F11 M14 T15 W16 T17 F18 M21 T22 W23 T24 F25
    //                   M28 T29 W30 = 15.
    expect(r.expected, 15);
  });

  // ── F. Future days excluded from present/absent/unmarked ──────────
  test('F: today mid-month → future days go to plannedFuture only', () {
    final prog = _program(daysOfWeek: const {1, 2, 3, 4, 5});
    final enr = _enrollment();
    final sessions = _monthSessions(prog, 2026, 9);
    final today = DateTime(2026, 9, 10);
    final r = computeAfterschoolMonthAttendance(
      childId: _childId,
      program: prog,
      year: 2026,
      month: 9,
      enrollments: [enr],
      sessionsInMonth: sessions,
      attendance: const [],
      today: today,
    );
    // Weekdays 1..10 = T1 W2 T3 F4 M7 T8 W9 T10 = 8 → expected past.
    // Weekdays 11..30 = 14.
    expect(r.expected, 8);
    expect(r.unmarked, 8);
    expect(r.plannedFuture, 14);
  });

  // ── G. Present counts ──────────────────────────────────────────────
  test('G: two present marks on past days', () {
    final prog = _program(daysOfWeek: const {1, 2, 3, 4, 5});
    final enr = _enrollment();
    final sessions = _monthSessions(prog, 2026, 9);
    final s1 = sessions.firstWhere(
        (s) => s.sessionDate == DateTime(2026, 9, 1));
    final s2 = sessions.firstWhere(
        (s) => s.sessionDate == DateTime(2026, 9, 2));
    final today = DateTime(2026, 9, 30);
    final r = computeAfterschoolMonthAttendance(
      childId: _childId,
      program: prog,
      year: 2026,
      month: 9,
      enrollments: [enr],
      sessionsInMonth: sessions,
      attendance: [
        _mark(s1, status: AttendanceStatus.present),
        _mark(s2, status: AttendanceStatus.present),
      ],
      today: today,
    );
    expect(r.expected, 22);
    expect(r.present, 2);
    expect(r.unmarked, 20);
    expect(r.lastPresenceDate, DateTime(2026, 9, 2));
  });

  // ── H. Absent counts ───────────────────────────────────────────────
  test('H: one absent mark on a past day', () {
    final prog = _program(daysOfWeek: const {1, 2, 3, 4, 5});
    final enr = _enrollment();
    final sessions = _monthSessions(prog, 2026, 9);
    final s = sessions.firstWhere(
        (s) => s.sessionDate == DateTime(2026, 9, 1));
    final today = DateTime(2026, 9, 30);
    final r = computeAfterschoolMonthAttendance(
      childId: _childId,
      program: prog,
      year: 2026,
      month: 9,
      enrollments: [enr],
      sessionsInMonth: sessions,
      attendance: [_mark(s, status: AttendanceStatus.absent)],
      today: today,
    );
    expect(r.expected, 22);
    expect(r.absent, 1);
    expect(r.unmarked, 21);
    expect(r.present, 0);
    expect(r.lastPresenceDate, isNull);
  });

  // ── I. Past expected day without attendance = unmarked ────────────
  test('I: past expected day, no session row → unmarked', () {
    final prog = _program(daysOfWeek: const {1, 2, 3, 4, 5});
    final enr = _enrollment();
    // Simulate a month where no sessions have been materialised.
    final today = DateTime(2026, 9, 30);
    final r = computeAfterschoolMonthAttendance(
      childId: _childId,
      program: prog,
      year: 2026,
      month: 9,
      enrollments: [enr],
      sessionsInMonth: const [],
      attendance: const [],
      today: today,
    );
    // Full expected denominator (22), all unmarked.
    expect(r.expected, 22);
    expect(r.unmarked, 22);
    expect(r.present, 0);
    expect(r.absent, 0);
  });

  // ── J. Weekday not in program.daysOfWeek isn't expected ───────────
  test('J: Saturday is never expected on an M-F program', () {
    final prog = _program(daysOfWeek: const {1, 2, 3, 4, 5});
    final enr = _enrollment();
    // Sept 2026: Saturdays = 5, 12, 19, 26. Session shouldn't exist,
    // but even if it does with a mark, the day isn't expected.
    final satSession = _session(DateTime(2026, 9, 5));
    final sessions = [..._monthSessions(prog, 2026, 9), satSession];
    final today = DateTime(2026, 9, 30);
    final r = computeAfterschoolMonthAttendance(
      childId: _childId,
      program: prog,
      year: 2026,
      month: 9,
      enrollments: [enr],
      sessionsInMonth: sessions,
      attendance: [_mark(satSession, status: AttendanceStatus.present)],
      today: today,
    );
    // Expected stays at 22 (Saturdays not eligible).
    expect(r.expected, 22);
    // The Saturday mark shows up in unexpected, not in present.
    expect(r.present, 0);
    expect(r.unexpected, 1);
  });

  // ── K. Unexpected attendance doesn't modify expected denominator ──
  test('K: unexpected marks are separate, do not change ratio', () {
    final prog = _program(daysOfWeek: const {1, 2, 3, 4, 5});
    // Child only expected on Mondays.
    final enr = _enrollment(attendanceDays: const {1});
    // Sessions exist for the full week; child was marked present on
    // a Wednesday (2026-09-02) even though not scheduled.
    final sessions = _monthSessions(prog, 2026, 9);
    final wed = sessions.firstWhere(
        (s) => s.sessionDate == DateTime(2026, 9, 2));
    final today = DateTime(2026, 9, 30);
    final r = computeAfterschoolMonthAttendance(
      childId: _childId,
      program: prog,
      year: 2026,
      month: 9,
      enrollments: [enr],
      sessionsInMonth: sessions,
      attendance: [_mark(wed, status: AttendanceStatus.present)],
      today: today,
    );
    // Mondays only: 7, 14, 21, 28 = 4.
    expect(r.expected, 4);
    expect(r.present, 0);
    expect(r.unmarked, 4);
    expect(r.unexpected, 1);
    // The unexpected present does NOT drive lastPresenceDate.
    expect(r.lastPresenceDate, isNull);
  });

  // ── L. Historical month, ended enrollment ─────────────────────────
  test('L: historical month, enrollment ended before "today"', () {
    final prog = _program(daysOfWeek: const {1, 2, 3, 4, 5});
    final enr = _enrollment(
      enrolledFrom: DateTime(2025, 6, 1),
      enrolledUntil: DateTime(2025, 12, 31),
      isActive: false,
    );
    final sessions = _monthSessions(prog, 2025, 8);
    final s = sessions.first;
    final today = DateTime(2026, 9, 30);
    final r = computeAfterschoolMonthAttendance(
      childId: _childId,
      program: prog,
      year: 2025,
      month: 8,
      enrollments: [enr],
      sessionsInMonth: sessions,
      attendance: [_mark(s, status: AttendanceStatus.present)],
      today: today,
    );
    // Aug 2025 M-F count = 21.
    expect(r.expected, 21);
    expect(r.present, 1);
    expect(r.unmarked, 20);
    expect(r.plannedFuture, 0);
    expect(r.lastPresenceDate, s.sessionDate);
  });

  // ── Bonus: closed session drops the day from expected entirely ────
  test('closed session removes the day from expected + unmarked', () {
    final prog = _program(daysOfWeek: const {1, 2, 3, 4, 5});
    final enr = _enrollment();
    final base = _monthSessions(prog, 2026, 9);
    final closedFirst = _session(DateTime(2026, 9, 1), isClosed: true);
    final sessions = [
      closedFirst,
      ...base.where((s) => s.sessionDate != DateTime(2026, 9, 1)),
    ];
    final today = DateTime(2026, 9, 30);
    final r = computeAfterschoolMonthAttendance(
      childId: _childId,
      program: prog,
      year: 2026,
      month: 9,
      enrollments: [enr],
      sessionsInMonth: sessions,
      attendance: const [],
      today: today,
    );
    // Sept M-F = 22, minus one closed = 21.
    expect(r.expected, 21);
    expect(r.unmarked, 21);
  });
}
