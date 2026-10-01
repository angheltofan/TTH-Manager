import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:tth_manager_app/features/afterschool/data/afterschool_attendance_repository.dart';
import 'package:tth_manager_app/features/afterschool/data/afterschool_enrollments_repository.dart';
import 'package:tth_manager_app/features/afterschool/data/afterschool_programs_repository.dart';
import 'package:tth_manager_app/features/afterschool/data/afterschool_sessions_repository.dart';
import 'package:tth_manager_app/features/afterschool/domain/afterschool_attendance.dart';
import 'package:tth_manager_app/features/afterschool/domain/afterschool_enrollment.dart';
import 'package:tth_manager_app/features/afterschool/domain/afterschool_program.dart';
import 'package:tth_manager_app/features/afterschool/domain/afterschool_session.dart';
import 'package:tth_manager_app/features/afterschool/providers/afterschool_providers.dart';

// Provider-level regression tests for the "attendance mark doesn't
// refresh the child profile" bug. These are the SEMANTIC contract the
// child-profile Afterschool panel + history row rely on:
//
//   • A new present/absent mark, invalidated through the family key
//     (childId, programId, year, month), MUST show up in
//     `afterschoolMonthAttendanceProvider` on the next read.
//   • The transitions UNMARKED → PRESENT, PRESENT → ABSENT,
//     ABSENT → UNMARKED produce the expected count deltas.
//   • `markAllPresent` fanned across N children must refresh N
//     separate month keys — invalidating only the program/day
//     surface is not enough.
//   • `AfterschoolChildMonthKey` equality is structural: two keys
//     with the same (childId, programId, year, month) resolve to
//     the same family instance.
//
// Fakes mirror the real repositories just enough to satisfy the
// providers. SupabaseClient is constructed but never touched because
// every method is overridden.

final _dummyClient =
    SupabaseClient('http://localhost', 'anon_key_placeholder');

const _programId = 'cccccccc-0000-0000-0000-000000000001';
const _childA = 'a0000000-0000-0000-0000-00000000000a';
const _childB = 'b0000000-0000-0000-0000-00000000000b';

AfterschoolProgram _program() => AfterschoolProgram(
      id: _programId,
      name: 'Test Program',
      daysOfWeek: const {1, 2, 3, 4, 5},
      startTime: '13:00:00',
      endTime: '17:00:00',
      monthlyFee: 1300,
      currency: 'RON',
      activeFrom: DateTime(2020, 1, 1),
      isActive: true,
      createdAt: DateTime(2020, 1, 1),
      updatedAt: DateTime(2020, 1, 1),
    );

AfterschoolSession _session(String id, DateTime date) =>
    AfterschoolSession(
      id: id,
      programId: _programId,
      sessionDate: date,
      startTime: '13:00:00',
      endTime: '17:00:00',
      isClosed: false,
      createdAt: date,
    );

/// Bounded enrollment that covers [enrolledFrom..enrolledUntil]. The
/// bounded window keeps the month-attendance computation deterministic
/// — only the enrolled days are "expected", regardless of how many
/// M-F days exist in the month.
AfterschoolEnrollment _enrollment({
  String childId = _childA,
  DateTime? enrolledFrom,
  DateTime? enrolledUntil,
}) =>
    AfterschoolEnrollment(
      id: 'enr-$childId',
      childId: childId,
      programId: _programId,
      enrolledFrom: enrolledFrom ?? DateTime(2026, 9, 1),
      enrolledUntil: enrolledUntil ?? DateTime(2026, 9, 3),
      attendanceDays: null,
      isActive: true,
      createdAt: DateTime(2020, 1, 1),
      updatedAt: DateTime(2020, 1, 1),
    );

AfterschoolAttendance _att(
    String sessionId, String childId, AttendanceStatus status) {
  return AfterschoolAttendance(
    id: 'att-$sessionId-$childId',
    sessionId: sessionId,
    childId: childId,
    status: status,
    observation: null,
    markedAt: DateTime(2026, 10, 1, 10, 0),
    markedBy: 'admin',
    updatedAt: DateTime(2026, 10, 1, 10, 0),
  );
}

class _FakeProgramsRepo extends AfterschoolProgramsRepository {
  _FakeProgramsRepo() : super(_dummyClient);
  @override
  Future<AfterschoolProgram?> fetchById(String id) async =>
      id == _programId ? _program() : null;
}

class _FakeEnrollmentsRepo extends AfterschoolEnrollmentsRepository {
  _FakeEnrollmentsRepo(this.rowsByChild) : super(_dummyClient);
  final Map<String, List<AfterschoolEnrollment>> rowsByChild;
  @override
  Future<List<AfterschoolEnrollment>> fetchForChild(String childId) async =>
      rowsByChild[childId] ?? const [];
}

class _FakeSessionsRepo extends AfterschoolSessionsRepository {
  _FakeSessionsRepo(this.sessions) : super(_dummyClient);
  final List<AfterschoolSession> sessions;
  @override
  Future<List<AfterschoolSession>> fetchForMonth({
    required String programId,
    required int year,
    required int month,
  }) async =>
      sessions
          .where((s) =>
              s.programId == programId &&
              s.sessionDate.year == year &&
              s.sessionDate.month == month)
          .toList();
}

class _FakeAttendanceRepo extends AfterschoolAttendanceRepository {
  _FakeAttendanceRepo(this.rows) : super(_dummyClient);
  List<AfterschoolAttendance> rows;
  int fetchForChildInSessionsCalls = 0;
  @override
  Future<List<AfterschoolAttendance>> fetchForChildInSessions({
    required String childId,
    required List<String> sessionIds,
  }) async {
    fetchForChildInSessionsCalls++;
    return rows
        .where((a) =>
            a.childId == childId && sessionIds.contains(a.sessionId))
        .toList();
  }
}

ProviderContainer _makeContainer({
  required _FakeSessionsRepo sessions,
  required _FakeAttendanceRepo attendance,
  _FakeEnrollmentsRepo? enrollments,
}) {
  final enrs = enrollments ??
      _FakeEnrollmentsRepo({
        _childA: [_enrollment(childId: _childA)],
        _childB: [_enrollment(childId: _childB)],
      });
  return ProviderContainer(overrides: [
    afterschoolProgramsRepositoryProvider.overrideWithValue(_FakeProgramsRepo()),
    afterschoolEnrollmentsRepositoryProvider.overrideWithValue(enrs),
    afterschoolSessionsRepositoryProvider.overrideWithValue(sessions),
    afterschoolAttendanceRepositoryProvider.overrideWithValue(attendance),
  ]);
}

void main() {
  group('afterschoolMonthAttendanceProvider — key equality', () {
    test('two keys with the same (childId, programId, year, month) '
        'are equal and share one provider instance', () {
      final k1 = AfterschoolChildMonthKey(
          childId: _childA, programId: _programId, year: 2026, month: 10);
      final k2 = AfterschoolChildMonthKey(
          childId: _childA, programId: _programId, year: 2026, month: 10);
      expect(k1, equals(k2));
      expect(k1.hashCode, equals(k2.hashCode));
      // One widget targets month-attendance via `k1`, another via
      // `k2`. Riverpod must resolve them to the SAME family entry so
      // a `ref.invalidate(provider(k1))` refreshes k2's watcher.
    });

    test('different month means different family entry (invalidating '
        'October must not invalidate November)', () {
      final oct = AfterschoolChildMonthKey(
          childId: _childA, programId: _programId, year: 2026, month: 10);
      final nov = AfterschoolChildMonthKey(
          childId: _childA, programId: _programId, year: 2026, month: 11);
      expect(oct, isNot(equals(nov)));
    });
  });

  group('afterschoolMonthAttendanceProvider — state transitions', () {
    // Three sessions in September 2026 — a fully-past month regardless
    // of when the test runs (DateTime.now() inside the provider body
    // is always after Sep 2026 for every realistic test clock). The
    // child's enrollment is bounded to Sep 1..Sep 3 so only those
    // three days enter the "expected" denominator.
    final sessions = [
      _session('s1', DateTime(2026, 9, 1)),
      _session('s2', DateTime(2026, 9, 2)),
      _session('s3', DateTime(2026, 9, 3)),
    ];

    final key = AfterschoolChildMonthKey(
        childId: _childA, programId: _programId, year: 2026, month: 9);

    Future<void> expectCounts(
      ProviderContainer c, {
      required int present,
      required int absent,
      required int unmarked,
    }) async {
      final att = await c.read(afterschoolMonthAttendanceProvider(key).future);
      expect(att, isNotNull);
      expect(att!.present, present, reason: 'present');
      expect(att.absent, absent, reason: 'absent');
      expect(att.unmarked, unmarked, reason: 'unmarked');
      // Invariant from the computation docstring.
      expect(att.expected, present + absent + unmarked);
    }

    test('UNMARKED → PRESENT: invalidation surfaces the new mark', () async {
      final attRepo = _FakeAttendanceRepo([]); // no marks yet
      final c = _makeContainer(
        sessions: _FakeSessionsRepo(sessions),
        attendance: attRepo,
      );
      addTearDown(c.dispose);

      // Initial read: 3 expected days, all unmarked.
      await expectCounts(c, present: 0, absent: 0, unmarked: 3);

      // Simulate upsertAttendance(sess1, Copil A, PRESENT) — the real
      // repo would INSERT; here we mutate the fake list, then the
      // dialog's invalidation surface fires.
      attRepo.rows = [_att('s1', _childA, AttendanceStatus.present)];
      c.invalidate(afterschoolMonthAttendanceProvider(key));

      // Child-profile panel must reflect the new present mark.
      await expectCounts(c, present: 1, absent: 0, unmarked: 2);
    });

    test('PRESENT → ABSENT: delta of −1 present / +1 absent', () async {
      final attRepo = _FakeAttendanceRepo([
        _att('s1', _childA, AttendanceStatus.present),
      ]);
      final c = _makeContainer(
        sessions: _FakeSessionsRepo(sessions),
        attendance: attRepo,
      );
      addTearDown(c.dispose);

      await expectCounts(c, present: 1, absent: 0, unmarked: 2);

      // Flip the single mark to absent (an UPSERT in the real repo).
      attRepo.rows = [_att('s1', _childA, AttendanceStatus.absent)];
      c.invalidate(afterschoolMonthAttendanceProvider(key));

      await expectCounts(c, present: 0, absent: 1, unmarked: 2);
    });

    test('ABSENT → UNMARKED: delete returns the row to the unmarked '
        'bucket', () async {
      final attRepo = _FakeAttendanceRepo([
        _att('s1', _childA, AttendanceStatus.absent),
      ]);
      final c = _makeContainer(
        sessions: _FakeSessionsRepo(sessions),
        attendance: attRepo,
      );
      addTearDown(c.dispose);

      await expectCounts(c, present: 0, absent: 1, unmarked: 2);

      attRepo.rows = const [];
      c.invalidate(afterschoolMonthAttendanceProvider(key));

      await expectCounts(c, present: 0, absent: 0, unmarked: 3);
    });

    test('invalidating the wrong month does NOT refresh the right '
        'month — proves the key equality is being honoured', () async {
      final attRepo = _FakeAttendanceRepo([]);
      final c = _makeContainer(
        sessions: _FakeSessionsRepo(sessions),
        attendance: attRepo,
      );
      addTearDown(c.dispose);

      // Prime October read.
      await expectCounts(c, present: 0, absent: 0, unmarked: 3);
      expect(attRepo.fetchForChildInSessionsCalls, 1);

      // Mutate underlying data, then invalidate a DIFFERENT month.
      attRepo.rows = [_att('s1', _childA, AttendanceStatus.present)];
      final nov = AfterschoolChildMonthKey(
          childId: _childA, programId: _programId, year: 2026, month: 11);
      c.invalidate(afterschoolMonthAttendanceProvider(nov));

      // October read still returns the primed (cached) value, no new
      // repo call. Riverpod MUST NOT cross-invalidate family entries.
      final attOct =
          await c.read(afterschoolMonthAttendanceProvider(key).future);
      expect(attOct!.present, 0);
      expect(attRepo.fetchForChildInSessionsCalls, 1);
    });
  });

  group('markAllPresent fans invalidation across every affected child',
      () {
    // One past session Sep 1 2026 (Tue). Each child enrolled only on
    // that day → expected=1 per child, no plannedFuture noise.
    final sess1 = _session('s1', DateTime(2026, 9, 1));

    final keyA = AfterschoolChildMonthKey(
        childId: _childA, programId: _programId, year: 2026, month: 9);
    final keyB = AfterschoolChildMonthKey(
        childId: _childB, programId: _programId, year: 2026, month: 9);

    // Both children enrolled only on Sep 1 to keep expected = 1
    // apiece.
    final enrs = _FakeEnrollmentsRepo({
      _childA: [
        _enrollment(
            childId: _childA,
            enrolledFrom: DateTime(2026, 9, 1),
            enrolledUntil: DateTime(2026, 9, 1)),
      ],
      _childB: [
        _enrollment(
            childId: _childB,
            enrolledFrom: DateTime(2026, 9, 1),
            enrolledUntil: DateTime(2026, 9, 1)),
      ],
    });

    test('invalidating only child A does not refresh child B — proves '
        'the operational page must loop over every expected child',
        () async {
      final attRepo = _FakeAttendanceRepo([]);
      final c = _makeContainer(
        sessions: _FakeSessionsRepo([sess1]),
        attendance: attRepo,
        enrollments: enrs,
      );
      addTearDown(c.dispose);

      // Prime both children's month views.
      final attAStart =
          await c.read(afterschoolMonthAttendanceProvider(keyA).future);
      final attBStart =
          await c.read(afterschoolMonthAttendanceProvider(keyB).future);
      expect(attAStart!.unmarked, 1);
      expect(attBStart!.unmarked, 1);

      // Server-side: mark both children present.
      attRepo.rows = [
        _att('s1', _childA, AttendanceStatus.present),
        _att('s1', _childB, AttendanceStatus.present),
      ];

      // Only invalidate A — simulate a buggy loop that forgot B.
      c.invalidate(afterschoolMonthAttendanceProvider(keyA));

      final attA =
          await c.read(afterschoolMonthAttendanceProvider(keyA).future);
      final attB =
          await c.read(afterschoolMonthAttendanceProvider(keyB).future);
      expect(attA!.present, 1, reason: 'A refreshed');
      expect(attB!.present, 0,
          reason:
              'B still cached — the operational page must invalidate per-child');
    });

    test('fanning invalidation over every expected child refreshes '
        'all of them', () async {
      final attRepo = _FakeAttendanceRepo([]);
      final c = _makeContainer(
        sessions: _FakeSessionsRepo([sess1]),
        attendance: attRepo,
        enrollments: enrs,
      );
      addTearDown(c.dispose);

      await c.read(afterschoolMonthAttendanceProvider(keyA).future);
      await c.read(afterschoolMonthAttendanceProvider(keyB).future);

      // Server: mark both present.
      attRepo.rows = [
        _att('s1', _childA, AttendanceStatus.present),
        _att('s1', _childB, AttendanceStatus.present),
      ];

      // Operational page _markAllPresent fans out:
      c.invalidate(afterschoolMonthAttendanceProvider(keyA));
      c.invalidate(afterschoolMonthAttendanceProvider(keyB));

      final attA =
          await c.read(afterschoolMonthAttendanceProvider(keyA).future);
      final attB =
          await c.read(afterschoolMonthAttendanceProvider(keyB).future);
      expect(attA!.present, 1);
      expect(attB!.present, 1);
    });
  });

  group('Unexpected attendance stays separate from expected counts',
      () {
    // Program M-F. One session on Saturday 2026-09-26 (ISO weekday
    // 6, past). The child's enrollment is bounded to Sep 1-3 so
    // weekdays outside that window don't inflate `expected`. The
    // Saturday mark should land in `unexpected`, not `present`.
    final satSession = _session('sat', DateTime(2026, 9, 26));
    final key = AfterschoolChildMonthKey(
        childId: _childA, programId: _programId, year: 2026, month: 9);

    test('a mark on an unexpected day never increments present nor '
        'the expected denominator', () async {
      final attRepo = _FakeAttendanceRepo([
        _att('sat', _childA, AttendanceStatus.present),
      ]);
      final c = _makeContainer(
        sessions: _FakeSessionsRepo([satSession]),
        attendance: attRepo,
      );
      addTearDown(c.dispose);

      final att = await c.read(afterschoolMonthAttendanceProvider(key).future);
      // Sat is not in daysOfWeek → the mark is unexpected.
      expect(att!.unexpected, 1);
      // Expected days come only from the bounded M-F enrollment
      // (Sep 1 Tue, Sep 2 Wed, Sep 3 Thu) — no sessions passed for
      // those, so they're unmarked, not present.
      expect(att.present, 0);
      expect(att.expected, 3);
      expect(att.unmarked, 3);
    });
  });
}
