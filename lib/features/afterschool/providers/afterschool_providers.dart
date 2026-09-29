import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/afterschool_attendance_repository.dart';
import '../data/afterschool_enrollments_repository.dart';
import '../data/afterschool_payments_repository.dart';
import '../data/afterschool_programs_repository.dart';
import '../data/afterschool_sessions_repository.dart';
import '../domain/afterschool_attendance.dart';
import '../domain/afterschool_enrollment.dart';
import '../domain/afterschool_program.dart';
import '../domain/afterschool_session.dart';

/// ── Repository singletons ────────────────────────────────────────────

final afterschoolProgramsRepositoryProvider =
    Provider<AfterschoolProgramsRepository>((ref) {
  return AfterschoolProgramsRepository(ref.watch(supabaseClientProvider));
});

final afterschoolEnrollmentsRepositoryProvider =
    Provider<AfterschoolEnrollmentsRepository>((ref) {
  return AfterschoolEnrollmentsRepository(
      ref.watch(supabaseClientProvider));
});

final afterschoolSessionsRepositoryProvider =
    Provider<AfterschoolSessionsRepository>((ref) {
  return AfterschoolSessionsRepository(ref.watch(supabaseClientProvider));
});

final afterschoolAttendanceRepositoryProvider =
    Provider<AfterschoolAttendanceRepository>((ref) {
  return AfterschoolAttendanceRepository(
      ref.watch(supabaseClientProvider));
});

final afterschoolPaymentsRepositoryProvider =
    Provider<AfterschoolPaymentsRepository>((ref) {
  return AfterschoolPaymentsRepository(ref.watch(supabaseClientProvider));
});

/// ── UI-facing providers (Phase 2) ────────────────────────────────────
///
/// Convention matches [workshops_providers.dart]: plain [FutureProvider]
/// for the list, [FutureProvider.family] for detail-by-id. Mutations in
/// forms invalidate the list + the specific by-id entry.

/// All Afterschool programs, active first (archived hidden by default).
/// Set `includeArchived: true` via `afterschoolAllProgramsProvider` when
/// the UI needs to show archived rows too (Phase 2 keeps them hidden).
final afterschoolProgramsProvider =
    FutureProvider<List<AfterschoolProgram>>((ref) async {
  final repo = ref.watch(afterschoolProgramsRepositoryProvider);
  return repo.fetchAll(activeOnly: true);
});

/// Same as [afterschoolProgramsProvider] but includes archived rows.
/// Used only by the "arhivate" toggle if we add one later; safe to keep
/// wired up now so the toggle doesn't require a code change.
final afterschoolAllProgramsProvider =
    FutureProvider<List<AfterschoolProgram>>((ref) async {
  final repo = ref.watch(afterschoolProgramsRepositoryProvider);
  return repo.fetchAll(activeOnly: false);
});

/// One program by id. Used by the detail page and the edit form.
final afterschoolProgramByIdProvider =
    FutureProvider.family<AfterschoolProgram?, String>((ref, id) async {
  final repo = ref.watch(afterschoolProgramsRepositoryProvider);
  return repo.fetchById(id);
});

/// Currently-active enrollments for one program (no `enrolled_until`,
/// `is_active = true`). This is what the detail page shows as the
/// "Copii înscriși" list and what the program form uses to compute the
/// impact preview of a `days_of_week` narrow.
final afterschoolActiveEnrollmentsForProgramProvider =
    FutureProvider.family<List<AfterschoolEnrollment>, String>(
  (ref, programId) async {
    final repo = ref.watch(afterschoolEnrollmentsRepositoryProvider);
    return repo.fetchActiveForProgram(programId);
  },
);

/// Active-enrollment count for one program. Cheap projection used by the
/// overview row ("N / max") and by the enrollment dialog to decide
/// whether to show the capacity warning. Backed by the id-only select
/// helper in the repo — the whole list is not fetched here.
final afterschoolActiveEnrollmentCountProvider =
    FutureProvider.family<int, String>((ref, programId) async {
  final repo = ref.watch(afterschoolEnrollmentsRepositoryProvider);
  return repo.countActiveForProgram(programId);
});

// ═════════════════════════════════════════════════════════════════════
// Phase 3 — Daily operations providers
// ═════════════════════════════════════════════════════════════════════

/// Program + date family key. Kept as a plain immutable value so
/// `.family` equality works: two `.family(...)` calls with the same
/// programId + dateKey resolve to the same provider instance.
class AfterschoolDayKey {
  const AfterschoolDayKey({required this.programId, required this.date});
  final String programId;
  final DateTime date;

  String get dateKey =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AfterschoolDayKey &&
          other.programId == programId &&
          other.dateKey == dateKey);

  @override
  int get hashCode => Object.hash(programId, dateKey);

  @override
  String toString() => 'AfterschoolDayKey($programId, $dateKey)';
}

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// Programs that could run on [date]: active, not archived, active
/// period covers the date, AND the date's ISO weekday is in the
/// program's days_of_week. Returns a filtered projection of
/// [afterschoolProgramsProvider] — no extra network round-trip.
final afterschoolApplicableProgramsForDateProvider =
    FutureProvider.family<List<AfterschoolProgram>, DateTime>(
        (ref, date) async {
  final all = await ref.watch(afterschoolProgramsProvider.future);
  final d = DateTime(date.year, date.month, date.day);
  final iso = d.weekday;
  return all.where((p) {
    if (!p.isActive || p.archivedAt != null) return false;
    if (d.isBefore(p.activeFrom)) return false;
    final to = p.activeTo;
    if (to != null && d.isAfter(to)) return false;
    return p.daysOfWeek.contains(iso);
  }).toList()
    ..sort((a, b) => a.startTime.compareTo(b.startTime));
});

/// The session row for (program, date). Behaviour matches the Phase 3
/// spec exactly:
///   • fetch first;
///   • if null AND (date <= today) AND the program is applicable that
///     day (verified via [afterschoolApplicableProgramsForDateProvider]),
///     invoke the idempotent RPC `generate_afterschool_sessions_window`
///     with `from == to == date` and re-fetch;
///   • future dates without an existing row → returns null (no
///     materialisation until the day arrives).
///
/// The RPC itself is the final gate — it silently skips inserts that
/// fall outside the program's active window or non-matching weekdays,
/// so even if the applicability filter drifts, no rogue rows land in
/// the DB.
final afterschoolSessionForDateProvider =
    FutureProvider.family<AfterschoolSession?, AfterschoolDayKey>(
        (ref, key) async {
  final repo = ref.watch(afterschoolSessionsRepositoryProvider);
  final existing = await repo.fetchByDate(programId: key.programId, date: key.date);
  if (existing != null) return existing;

  // No row. Only lazy-generate for present-or-past dates.
  final today = _today();
  final d = DateTime(key.date.year, key.date.month, key.date.day);
  if (d.isAfter(today)) return null;

  // Verify applicability BEFORE calling the RPC, to keep the round-trip
  // count minimal on dates the program couldn't have run anyway
  // (weekends, before active_from, etc.).
  final applicable =
      await ref.read(afterschoolApplicableProgramsForDateProvider(d).future);
  if (!applicable.any((p) => p.id == key.programId)) {
    return null;
  }

  // Idempotent server-side generation. Server clamps to program window
  // and skips non-matching weekdays, so this is safe even if the
  // client-side check above is somehow wrong.
  await repo.generateWindow(programId: key.programId, from: d, to: d);
  return repo.fetchByDate(programId: key.programId, date: d);
});

/// Enrollments expected on [date] for [programId]. Applies the domain
/// helper `AfterschoolEnrollment.isExpectedForDate` — coversDate AND
/// followsWeekday. Rows a child ended before that date, or that don't
/// follow the date's weekday, are filtered out.
final afterschoolExpectedEnrollmentsForDateProvider =
    FutureProvider.family<List<AfterschoolEnrollment>, AfterschoolDayKey>(
        (ref, key) async {
  final repo = ref.watch(afterschoolEnrollmentsRepositoryProvider);
  final rows = await repo.fetchCoveringDate(
      programId: key.programId, date: key.date);
  return rows.where((e) => e.isExpectedForDate(key.date)).toList();
});

/// Every attendance row for [sessionId]. Empty if the session has no
/// marks yet. Ordered by marked_at ASC so latest changes appear
/// last (the UI keeps its own render order anyway).
final afterschoolAttendanceForSessionProvider =
    FutureProvider.family<List<AfterschoolAttendance>, String>(
        (ref, sessionId) async {
  final repo = ref.watch(afterschoolAttendanceRepositoryProvider);
  return repo.fetchForSession(sessionId);
});

/// Compact summary emitted by the "Astăzi" tile: expected / present /
/// absent / unmarked, plus whether the session exists / is closed and
/// which attendance rows are "unexpected" (marked but child no longer
/// in the eligible list — usually because their enrollment.attendance_days
/// was narrowed after the mark). The Astăzi tile uses only the counts;
/// the detail page uses `unexpectedAttendance` to render the secondary
/// "Prezențe în afara programului zilei" section.
class AfterschoolDaySummary {
  const AfterschoolDaySummary({
    required this.expected,
    required this.attendance,
    required this.unexpectedAttendance,
    required this.session,
  });

  final List<AfterschoolEnrollment> expected;
  final List<AfterschoolAttendance> attendance;

  /// Attendance rows whose child is NOT in [expected]. Kept as
  /// attendance rows (not enrollments) so the UI can still render name
  /// + status even if the enrollment's `attendance_days` changed after
  /// the mark. Rare, but must not vanish silently.
  final List<AfterschoolAttendance> unexpectedAttendance;

  final AfterschoolSession? session;

  int get expectedCount => expected.length;

  int get presentCount => attendance
      .where((a) => expected.any((e) => e.childId == a.childId))
      .where((a) => a.status == AttendanceStatus.present)
      .length;

  int get absentCount => attendance
      .where((a) => expected.any((e) => e.childId == a.childId))
      .where((a) => a.status == AttendanceStatus.absent)
      .length;

  int get unmarkedCount {
    // A child in [expected] with no matching attendance row is unmarked.
    return expected.where((e) {
      return !attendance.any((a) => a.childId == e.childId);
    }).length;
  }

  bool get isClosed => session?.isClosed ?? false;
  bool get sessionExists => session != null;
}

/// Aggregation provider — combines session + expected + attendance for
/// (program, date) into a single AsyncValue the UI cards consume.
final afterschoolDaySummaryProvider =
    FutureProvider.family<AfterschoolDaySummary, AfterschoolDayKey>(
        (ref, key) async {
  final session =
      await ref.watch(afterschoolSessionForDateProvider(key).future);
  final expected = await ref
      .watch(afterschoolExpectedEnrollmentsForDateProvider(key).future);

  final attendance = session == null
      ? const <AfterschoolAttendance>[]
      : await ref.watch(
          afterschoolAttendanceForSessionProvider(session.id).future);

  final expectedIds = expected.map((e) => e.childId).toSet();
  final unexpected =
      attendance.where((a) => !expectedIds.contains(a.childId)).toList();

  return AfterschoolDaySummary(
    expected: expected,
    attendance: attendance,
    unexpectedAttendance: unexpected,
    session: session,
  );
});

/// Convenience: the current user's id, used by attendance widgets so
/// they don't each re-read the profile provider. Returns empty string
/// when the profile isn't ready yet (never called before login gates).
final currentUserIdProvider = Provider<String>((ref) {
  final profile = ref.watch(currentProfileProvider).valueOrNull;
  return profile?.id ?? '';
});
