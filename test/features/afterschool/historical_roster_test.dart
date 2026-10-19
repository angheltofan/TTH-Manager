import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:tth_manager_app/features/afterschool/data/afterschool_enrollments_repository.dart';
import 'package:tth_manager_app/features/afterschool/domain/afterschool_enrollment.dart';
import 'package:tth_manager_app/features/afterschool/providers/afterschool_providers.dart';

// Regression: "Afterschool past-date attendance doesn't work".
//
// Root cause: `fetchCoveringDate` filtered on `is_active = true`.
// `endEnrollment` writes BOTH `enrolled_until = <date>` AND
// `is_active = false` atomically — so every historical cohort that
// has since been un-enrolled was hidden from the past-date roster,
// which gates the attendance toggles on `sessionExists && expected`.
//
// The fix drops the `is_active` filter: the date interval is now
// authoritative. These tests exercise the semantic contract the
// repository must honour after the fix, without touching the network.

final _dummyClient =
    SupabaseClient('http://localhost', 'anon_key_placeholder');

const _programId = 'cccccccc-0000-0000-0000-000000000001';

AfterschoolEnrollment _enr({
  required String id,
  required String childId,
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

/// Fake repo whose `fetchCoveringDate` emulates the FIXED SQL
/// predicate — `enrolled_from <= date AND (enrolled_until IS NULL OR
/// enrolled_until >= date)` — with NO `is_active` filter. Mirrors the
/// real repo so the tests prove the contract end-to-end.
class _HistoricalRepoFake extends AfterschoolEnrollmentsRepository {
  _HistoricalRepoFake(this.rows) : super(_dummyClient);
  final List<AfterschoolEnrollment> rows;

  @override
  Future<List<AfterschoolEnrollment>> fetchCoveringDate({
    required String programId,
    required DateTime date,
  }) async {
    final d = DateTime(date.year, date.month, date.day);
    return rows.where((e) {
      if (e.programId != programId) return false;
      if (e.enrolledFrom.isAfter(d)) return false;
      final until = e.enrolledUntil;
      if (until != null && d.isAfter(until)) return false;
      return true;
    }).toList();
  }
}

void main() {
  group('fetchCoveringDate historical contract (post-fix)', () {
    // 2026-10-01 is a Thursday — ISO weekday 4.
    final today = DateTime(2026, 10, 1);
    final pastDate = DateTime(2026, 8, 15); // Saturday, ISO=6
    // Pick a past WEEKDAY date so expected provider actually derives
    // the row (program days_of_week typically Mon-Fri).
    final pastWeekday = DateTime(2026, 8, 14); // Friday, ISO=5

    ProviderContainer makeContainer(_HistoricalRepoFake fake) =>
        ProviderContainer(overrides: [
          afterschoolEnrollmentsRepositoryProvider.overrideWithValue(fake),
        ]);

    test('child whose enrollment was ENDED (is_active=false, '
        'enrolled_until set) still appears on a past date within '
        'the enrolled interval', () async {
      final fake = _HistoricalRepoFake([
        _enr(
          id: 'ended-1',
          childId: 'child-a',
          enrolledFrom: DateTime(2026, 6, 1),
          enrolledUntil: DateTime(2026, 9, 30),
          attendanceDays: {1, 2, 3, 4, 5},
          isActive: false, // ← key: ended but historically covered
        ),
        _enr(
          id: 'active-1',
          childId: 'child-b',
          enrolledFrom: DateTime(2026, 7, 1),
          attendanceDays: {1, 2, 3, 4, 5},
          isActive: true,
        ),
      ]);
      final container = makeContainer(fake);
      addTearDown(container.dispose);

      final roster = await container.read(
        afterschoolRosterForDateProvider(
          AfterschoolDayKey(programId: _programId, date: pastWeekday),
        ).future,
      );

      expect(roster.map((e) => e.childId),
          containsAll(['child-a', 'child-b']),
          reason:
              'child-a (ended) must appear because enrolled interval '
              'covers 2026-08-14; child-b (active) covers it too');
    });

    test('ended enrollment is EXCLUDED after enrolled_until', () async {
      final fake = _HistoricalRepoFake([
        _enr(
          id: 'ended-1',
          childId: 'child-a',
          enrolledFrom: DateTime(2026, 6, 1),
          enrolledUntil: DateTime(2026, 7, 31),
          isActive: false,
        ),
      ]);
      final container = makeContainer(fake);
      addTearDown(container.dispose);

      final roster = await container.read(
        afterschoolRosterForDateProvider(
          AfterschoolDayKey(programId: _programId, date: pastWeekday),
        ).future,
      );
      expect(roster, isEmpty,
          reason: '2026-08-14 is AFTER enrolled_until=2026-07-31; '
              'the row must drop out via the date interval');
    });

    test('ended enrollment is EXCLUDED before enrolled_from', () async {
      final fake = _HistoricalRepoFake([
        _enr(
          id: 'ended-1',
          childId: 'child-a',
          enrolledFrom: DateTime(2026, 9, 1),
          enrolledUntil: DateTime(2026, 11, 30),
          isActive: false,
        ),
      ]);
      final container = makeContainer(fake);
      addTearDown(container.dispose);

      final roster = await container.read(
        afterschoolRosterForDateProvider(
          AfterschoolDayKey(programId: _programId, date: pastWeekday),
        ).future,
      );
      expect(roster, isEmpty,
          reason: '2026-08-14 is BEFORE enrolled_from=2026-09-01');
    });

    test('today\'s roster includes both active and inactive '
        'enrollments whose interval still covers today', () async {
      // An inactive enrollment with enrolled_until = today is still
      // "coveringToday" — the last day is inclusive. The user should
      // see this child on today's roster so they can mark the final
      // attendance before the row leaves the operational view
      // tomorrow.
      final fake = _HistoricalRepoFake([
        _enr(
          id: 'closing-today',
          childId: 'child-last',
          enrolledFrom: DateTime(2026, 7, 1),
          enrolledUntil: today,
          isActive: false, // ← ended but inclusive of today
        ),
        _enr(
          id: 'open',
          childId: 'child-open',
          enrolledFrom: DateTime(2026, 7, 1),
          isActive: true,
        ),
      ]);
      final container = makeContainer(fake);
      addTearDown(container.dispose);

      final roster = await container.read(
        afterschoolRosterForDateProvider(
          AfterschoolDayKey(programId: _programId, date: today),
        ).future,
      );
      expect(roster.map((e) => e.childId),
          containsAll(['child-last', 'child-open']));
    });

    test('expected-today derivation still works for revived '
        'historical rows: a formerly-active enrollment on a past '
        'weekday matching attendance_days is BOTH in the roster AND '
        'in the expected set', () async {
      final fake = _HistoricalRepoFake([
        _enr(
          id: 'ended-expected',
          childId: 'child-x',
          enrolledFrom: DateTime(2026, 6, 1),
          enrolledUntil: DateTime(2026, 9, 30),
          attendanceDays: {5}, // only Fridays
          isActive: false,
        ),
      ]);
      final container = makeContainer(fake);
      addTearDown(container.dispose);

      final key = AfterschoolDayKey(programId: _programId, date: pastWeekday);
      final roster =
          await container.read(afterschoolRosterForDateProvider(key).future);
      final expected = await container.read(
          afterschoolExpectedEnrollmentsForDateProvider(key).future);
      expect(roster.length, 1);
      expect(expected.length, 1,
          reason: '2026-08-14 is a Friday; attendance_days includes 5');
    });

    test('weekend past-date (Saturday) returns in roster but NOT '
        'expected when attendance_days excludes it', () async {
      // Saturday is unusual for afterschool, but confirms the
      // weekday-filter chain still works post-fix.
      final fake = _HistoricalRepoFake([
        _enr(
          id: 'weekday-only',
          childId: 'child-x',
          enrolledFrom: DateTime(2026, 6, 1),
          enrolledUntil: DateTime(2026, 9, 30),
          attendanceDays: {1, 2, 3, 4, 5}, // weekdays only
          isActive: false,
        ),
      ]);
      final container = makeContainer(fake);
      addTearDown(container.dispose);

      final key = AfterschoolDayKey(programId: _programId, date: pastDate);
      final roster =
          await container.read(afterschoolRosterForDateProvider(key).future);
      final expected = await container.read(
          afterschoolExpectedEnrollmentsForDateProvider(key).future);
      expect(roster.length, 1,
          reason: 'enrollment covers 2026-08-15 → in roster');
      expect(expected, isEmpty,
          reason: '2026-08-15 is Saturday (ISO=6), not in attendance_days');
    });
  });
}
