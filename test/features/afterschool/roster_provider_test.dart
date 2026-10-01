import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:tth_manager_app/features/afterschool/data/afterschool_enrollments_repository.dart';
import 'package:tth_manager_app/features/afterschool/domain/afterschool_enrollment.dart';
import 'package:tth_manager_app/features/afterschool/providers/afterschool_providers.dart';

// Provider-level regression tests for the enrollment visibility bug.
// Scope — the SEMANTIC contract the operational page relies on:
//
//   • `afterschoolRosterForDateProvider` returns every enrollment
//     that covers the selected date, regardless of weekday.
//   • `afterschoolExpectedEnrollmentsForDateProvider` is derived from
//     the roster — one DB round-trip serves both.
//   • Invalidating the roster surface after a mutation causes the
//     expected family (and anything downstream in the page summary)
//     to pick up the new row immediately, without waiting for the
//     Supabase realtime round-trip. This is what the three dialogs
//     (enroll / edit / end) must do.
//
// A `_FakeEnrollmentsRepo` holds a mutable in-memory list of rows and
// counts calls to `fetchCoveringDate`, so the tests prove the two
// providers share a single fetch per read of the roster.

// SupabaseClient is constructed but never used by the fake repo —
// `fetchCoveringDate` is overridden to serve the in-memory list, so
// the HTTP client never gets touched.
final _dummyClient =
    SupabaseClient('http://localhost', 'anon_key_placeholder');

const _programId = 'cccccccc-0000-0000-0000-000000000001';

AfterschoolEnrollment _enr({
  required String id,
  String childId = 'child-x',
  DateTime? enrolledFrom,
  DateTime? enrolledUntil,
  Set<int>? attendanceDays,
  bool isActive = true,
}) =>
    AfterschoolEnrollment(
      id: id,
      childId: childId,
      programId: _programId,
      enrolledFrom: enrolledFrom ?? DateTime(2026, 1, 1),
      enrolledUntil: enrolledUntil,
      attendanceDays: attendanceDays,
      isActive: isActive,
      createdAt: DateTime(2020, 1, 1),
      updatedAt: DateTime(2020, 1, 1),
    );

class _FakeEnrollmentsRepo extends AfterschoolEnrollmentsRepository {
  _FakeEnrollmentsRepo(this.rows) : super(_dummyClient);

  List<AfterschoolEnrollment> rows;
  int fetchCoveringDateCalls = 0;

  @override
  Future<List<AfterschoolEnrollment>> fetchCoveringDate({
    required String programId,
    required DateTime date,
  }) async {
    fetchCoveringDateCalls++;
    return rows
        .where((e) =>
            e.programId == programId && e.isActive && e.coversDate(date))
        .toList();
  }
}

void main() {
  group('afterschoolRosterForDateProvider + expected (one DB call)', () {
    final today = DateTime(2026, 10, 1); // Thursday, ISO=4
    final key = AfterschoolDayKey(programId: _programId, date: today);

    test('expected is derived from roster: a single fetchCoveringDate '
        'call serves both providers', () async {
      final fake = _FakeEnrollmentsRepo([
        _enr(id: 'A', childId: 'c-a', attendanceDays: null),
        _enr(id: 'B', childId: 'c-b', attendanceDays: {1, 3, 5}),
        _enr(id: 'C', childId: 'c-c', attendanceDays: {4}),
      ]);
      final c = ProviderContainer(overrides: [
        afterschoolEnrollmentsRepositoryProvider.overrideWithValue(fake),
      ]);
      addTearDown(c.dispose);

      final roster = await c.read(afterschoolRosterForDateProvider(key).future);
      final expected = await c
          .read(afterschoolExpectedEnrollmentsForDateProvider(key).future);

      // One fetch for both — expected watches the roster future.
      expect(fake.fetchCoveringDateCalls, 1);
      // Roster has 3 rows (all cover the date).
      expect(roster.map((e) => e.id).toSet(), {'A', 'B', 'C'});
      // Expected drops B (Thu not in {1,3,5}).
      expect(expected.map((e) => e.id).toSet(), {'A', 'C'});
    });

    test('invalidating the roster re-fetches and both providers pick '
        'up the new enrollment', () async {
      final fake = _FakeEnrollmentsRepo([
        _enr(id: 'A', childId: 'c-a', attendanceDays: null),
      ]);
      final c = ProviderContainer(overrides: [
        afterschoolEnrollmentsRepositoryProvider.overrideWithValue(fake),
      ]);
      addTearDown(c.dispose);

      // Initial read — 1 row.
      var roster =
          await c.read(afterschoolRosterForDateProvider(key).future);
      expect(roster.map((e) => e.id).toSet(), {'A'});
      expect(fake.fetchCoveringDateCalls, 1);

      // Simulate the enroll dialog: push a new row through the fake
      // (mirrors what a real INSERT via the repo would end up as a
      // read), then invalidate — exactly what `enroll_child_dialog`
      // does after `repo.create(...)`.
      fake.rows = [
        ...fake.rows,
        _enr(id: 'B', childId: 'c-b', attendanceDays: null),
      ];
      c.invalidate(afterschoolRosterForDateProvider);
      c.invalidate(afterschoolExpectedEnrollmentsForDateProvider);

      // Both providers must reflect the new row on the next read.
      roster = await c.read(afterschoolRosterForDateProvider(key).future);
      final expected = await c
          .read(afterschoolExpectedEnrollmentsForDateProvider(key).future);
      expect(roster.map((e) => e.id).toSet(), {'A', 'B'});
      expect(expected.map((e) => e.id).toSet(), {'A', 'B'});
    });

    test('invalidating the roster also drops rows ended via the end '
        'enrollment dialog', () async {
      final fake = _FakeEnrollmentsRepo([
        _enr(id: 'A', childId: 'c-a', attendanceDays: null),
        _enr(id: 'B', childId: 'c-b', attendanceDays: null),
      ]);
      final c = ProviderContainer(overrides: [
        afterschoolEnrollmentsRepositoryProvider.overrideWithValue(fake),
      ]);
      addTearDown(c.dispose);

      var roster =
          await c.read(afterschoolRosterForDateProvider(key).future);
      expect(roster.map((e) => e.id).toSet(), {'A', 'B'});

      // Simulate end-enrollment on B: `enrolled_until = yesterday`,
      // `is_active = false`. The roster for today must drop B.
      fake.rows = [
        _enr(id: 'A', childId: 'c-a', attendanceDays: null),
        _enr(
          id: 'B',
          childId: 'c-b',
          enrolledUntil: DateTime(2026, 9, 30),
          isActive: false,
        ),
      ];
      c.invalidate(afterschoolRosterForDateProvider);

      roster = await c.read(afterschoolRosterForDateProvider(key).future);
      expect(roster.map((e) => e.id).toSet(), {'A'});
    });
  });
}
