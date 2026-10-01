import 'afterschool_attendance.dart';
import 'afterschool_enrollment.dart';
import 'afterschool_program.dart';
import 'afterschool_session.dart';

/// Per-child, per-(program, year, month) attendance snapshot used by the
/// Child Details "Afterschool" panel. All counts are computed from the
/// (program, enrollments-for-this-child, sessions-in-month, attendance-
/// rows-for-this-child, today) tuple. Pure — no Supabase access.
///
/// Semantics (as agreed in the Phase-4 UI-integration spec):
///
///   • **Expected day** = the program is applicable that date
///     (isEligibleDay: active window + program's `daysOfWeek`) AND
///     the child's enrollment covers the date AND, if the enrollment
///     has a per-child `attendanceDays` override, the ISO weekday is
///     inside it, AND the session for that date is NOT closed. Closed
///     days (holiday / center shut) are dropped from BOTH numerator
///     and denominator.
///
///   • For every past-or-today expected day the child's attendance row
///     (matched by `session_id`) resolves to one of:
///         `present` (`status = present`)
///         `absent`  (`status = absent`)
///         `unmarked` (no row — deliberately NOT the same as absent)
///
///   • **Future expected days** are excluded from present/absent/
///     unmarked entirely; they surface separately as [plannedFuture]
///     so the UI can render "+ N planificate" without polluting the
///     denominator.
///
///   • **Unexpected attendance** = an attendance row whose session
///     falls in the month AND references this child, but the day is
///     NOT expected (e.g. the child arrived on a day they weren't
///     scheduled). These do NOT enter the expected denominator and do
///     NOT change present/absent/unmarked for expected days. They are
///     surfaced separately as [unexpected] for audit.
///
///   • [lastPresenceDate] is the most recent past-or-today expected
///     day on which the child was marked present.
///
/// Invariant: `expected == present + absent + unmarked`.
class AfterschoolMonthAttendance {
  const AfterschoolMonthAttendance({
    required this.childId,
    required this.programId,
    required this.year,
    required this.month,
    required this.expected,
    required this.present,
    required this.absent,
    required this.unmarked,
    required this.plannedFuture,
    required this.unexpected,
    required this.lastPresenceDate,
    required this.today,
  });

  final String childId;
  final String programId;
  final int year;
  final int month;

  /// Expected past-or-today days (denominator for the ratio).
  final int expected;
  final int present;
  final int absent;
  final int unmarked;

  /// Expected days that are still in the future for [today]. Never
  /// enters [expected] / present / absent / unmarked; shown separately.
  final int plannedFuture;

  /// Attendance rows on days the child was NOT expected. See doc above.
  final int unexpected;

  /// Most recent past-or-today expected day the child was present on.
  final DateTime? lastPresenceDate;

  final DateTime today;

  /// True when there are neither past-expected days nor future-planned
  /// days for this child in the month — used by the UI to render a
  /// friendlier "no schedule this month" empty state.
  bool get isEmpty =>
      expected == 0 && plannedFuture == 0 && unexpected == 0;
}

/// Pure computation. Deterministic, side-effect-free.
///
/// Only the inputs actually needed by the algorithm are required:
///
///   * [childId]      — the child whose attendance we're computing.
///   * [program]      — for `daysOfWeek` and `[activeFrom, activeTo]`.
///   * [enrollments]  — every enrollment row for this child in this
///                      program (any state). Overlapping periods are
///                      tolerated; a day is expected if ANY enrollment
///                      covers it AND follows the weekday. Historical
///                      inactive rows still contribute to past-month
///                      attendance so ended enrollments don't lose
///                      their history from the profile view.
///   * [sessionsInMonth] — every session for this program in the
///                      target month, regardless of open/closed.
///   * [attendance]   — every attendance row for this child in
///                      [sessionsInMonth]. Rows outside those sessions
///                      are ignored (defensive).
///   * [today]        — used to split past vs. future.
AfterschoolMonthAttendance computeAfterschoolMonthAttendance({
  required String childId,
  required AfterschoolProgram program,
  required int year,
  required int month,
  required List<AfterschoolEnrollment> enrollments,
  required List<AfterschoolSession> sessionsInMonth,
  required List<AfterschoolAttendance> attendance,
  required DateTime today,
}) {
  final normalizedToday = DateTime(today.year, today.month, today.day);
  final lastDayOfMonth = DateTime(year, month + 1, 0).day;

  // Index sessions by yyyy-mm-dd for fast lookup. If the DB has more
  // than one row for the same date (should never happen — unique
  // index), the last one wins.
  final sessionByDate = <String, AfterschoolSession>{
    for (final s in sessionsInMonth)
      if (s.programId == program.id) _isoDate(s.sessionDate): s,
  };

  // Attendance by session id.
  final attBySessionId = <String, AfterschoolAttendance>{
    for (final a in attendance) a.sessionId: a,
  };

  // Enrollments filtered to this child (defensive — the caller is
  // expected to pass a per-child list, but we accept a wider input).
  final childEnrollments =
      enrollments.where((e) => e.childId == childId).toList();

  int expected = 0;
  int present = 0;
  int absent = 0;
  int unmarked = 0;
  int plannedFuture = 0;
  DateTime? lastPresence;

  final expectedDates = <String>{};

  for (var day = 1; day <= lastDayOfMonth; day++) {
    final date = DateTime(year, month, day);

    if (!program.isEligibleDay(date)) continue;

    // The child needs at least one enrollment that covers the date
    // AND — if the enrollment has an override — includes the weekday.
    final expectedByEnrollment = childEnrollments.any((e) {
      if (!e.coversDate(date)) return false;
      return e.followsWeekday(date.weekday);
    });
    if (!expectedByEnrollment) continue;

    // If a session exists for that day AND is closed, the day isn't
    // eligible for anyone — closed doesn't count as expected.
    final session = sessionByDate[_isoDate(date)];
    if (session != null && session.isClosed) continue;

    expectedDates.add(_isoDate(date));

    if (date.isAfter(normalizedToday)) {
      plannedFuture++;
      continue;
    }

    expected++;

    // Match attendance by session id, if a session row exists.
    final att = session == null ? null : attBySessionId[session.id];
    if (att == null) {
      unmarked++;
      continue;
    }
    switch (att.status) {
      case AttendanceStatus.present:
        present++;
        if (lastPresence == null || date.isAfter(lastPresence)) {
          lastPresence = date;
        }
      case AttendanceStatus.absent:
        absent++;
    }
  }

  // Unexpected = attendance rows in the month whose session's date
  // wasn't in the expected set. Uses whatever session data we have —
  // a session must exist for an attendance row to reference it, so
  // sessionByDate lookup is enough.
  var unexpected = 0;
  for (final a in attendance) {
    // Find the session for this row inside the month.
    AfterschoolSession? session;
    for (final s in sessionsInMonth) {
      if (s.id == a.sessionId) {
        session = s;
        break;
      }
    }
    if (session == null) continue;
    if (session.sessionDate.year != year || session.sessionDate.month != month) {
      continue;
    }
    final key = _isoDate(session.sessionDate);
    if (!expectedDates.contains(key)) unexpected++;
  }

  return AfterschoolMonthAttendance(
    childId: childId,
    programId: program.id,
    year: year,
    month: month,
    expected: expected,
    present: present,
    absent: absent,
    unmarked: unmarked,
    plannedFuture: plannedFuture,
    unexpected: unexpected,
    lastPresenceDate: lastPresence,
    today: normalizedToday,
  );
}

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
