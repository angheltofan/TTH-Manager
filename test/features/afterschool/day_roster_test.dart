import 'package:flutter_test/flutter_test.dart';

import 'package:tth_manager_app/features/afterschool/domain/afterschool_enrollment.dart';

// Regression tests for the operational-page roster bug (TTH Manager
// Phase 4 Afterschool). Pure domain semantics — no Riverpod, no
// widgets. The product rules exercised here:
//
//   • A child being ENROLLED and a child being EXPECTED on a date
//     are different things.
//   • "Copii înscriși" shows every enrollment covering the date
//     (`coversDate`), not only the day-eligible subset.
//   • `isExpectedForDate` requires BOTH coversDate AND followsWeekday.
//
// Cases A..G mirror STEP 6 of the bug report.

const _programId = 'cccccccc-0000-0000-0000-000000000001';
const _childId = 'a0000000-0000-0000-0000-00000000000a';

AfterschoolEnrollment _enrollment({
  required String id,
  DateTime? enrolledFrom,
  DateTime? enrolledUntil,
  Set<int>? attendanceDays,
  bool isActive = true,
}) =>
    AfterschoolEnrollment(
      id: id,
      childId: _childId,
      programId: _programId,
      enrolledFrom: enrolledFrom ?? DateTime(2026, 1, 1),
      enrolledUntil: enrolledUntil,
      attendanceDays: attendanceDays,
      isActive: isActive,
      createdAt: DateTime(2020, 1, 1),
      updatedAt: DateTime(2020, 1, 1),
    );

void main() {
  group('Roster vs expected (STEP 6 cases)', () {
    // 2026-10-01 is a Thursday — ISO weekday 4.
    final today = DateTime(2026, 10, 1);
    final yesterday = DateTime(2026, 9, 30); // Wed (3)

    test('A: starts today, attendance_days includes today → expected '
        'AND in roster', () {
      final e = _enrollment(
        id: 'A',
        enrolledFrom: today,
        attendanceDays: {1, 2, 3, 4, 5},
      );
      expect(e.coversDate(today), isTrue, reason: 'roster');
      expect(e.isExpectedForDate(today), isTrue, reason: 'expected');
    });

    test('B: starts today, attendance_days EXCLUDES today → in roster '
        'but NOT expected (the primary bug: must not disappear from UI)',
        () {
      final e = _enrollment(
        id: 'B',
        enrolledFrom: today,
        attendanceDays: {1, 3, 5}, // Mon/Wed/Fri — Thu excluded
      );
      expect(e.coversDate(today), isTrue,
          reason: 'roster still includes the row');
      expect(e.isExpectedForDate(today), isFalse,
          reason: 'row shows "Nu participă azi", no attendance toggles');
    });

    test('C: attendance_days == null → child follows every program day',
        () {
      final e = _enrollment(
        id: 'C',
        enrolledFrom: DateTime(2026, 1, 1),
        attendanceDays: null,
      );
      // Still gated by weekday only at the program level (checked
      // separately by the page's session-exists state). From the
      // enrollment's own perspective, every day it covers is expected.
      expect(e.coversDate(today), isTrue);
      expect(e.isExpectedForDate(today), isTrue);
    });

    test('D: starts tomorrow → not in roster for today, not expected',
        () {
      final e = _enrollment(
        id: 'D',
        enrolledFrom: DateTime(2026, 10, 2), // Fri
      );
      expect(e.coversDate(today), isFalse);
      expect(e.isExpectedForDate(today), isFalse);
    });

    test('E: ended yesterday → not in roster for today', () {
      final e = _enrollment(
        id: 'E',
        enrolledFrom: DateTime(2026, 1, 1),
        enrolledUntil: yesterday,
        isActive: false,
      );
      expect(e.coversDate(today), isFalse);
      expect(e.isExpectedForDate(today), isFalse);
      // ...but yesterday the roster did include this child.
      expect(e.coversDate(yesterday), isTrue);
    });

    test('F: edit attendance_days to exclude today → next read must '
        'drop from expected without affecting roster membership', () {
      // Simulate pre- and post-edit snapshots. The repository returns
      // a fresh row each time; the UI's expected set recomputes from
      // the new row's `attendance_days`.
      final before = _enrollment(
        id: 'F',
        enrolledFrom: DateTime(2026, 1, 1),
        attendanceDays: null,
      );
      final after = _enrollment(
        id: 'F',
        enrolledFrom: DateTime(2026, 1, 1),
        attendanceDays: {1}, // Mon only
      );
      expect(before.isExpectedForDate(today), isTrue);
      expect(after.isExpectedForDate(today), isFalse);
      // Roster membership (coversDate) is identical pre/post.
      expect(before.coversDate(today), equals(after.coversDate(today)));
    });

    test('G: end enrollment at date X → roster drops the child from X+1',
        () {
      final ended = _enrollment(
        id: 'G',
        enrolledFrom: DateTime(2026, 1, 1),
        enrolledUntil: today,
        isActive: false,
      );
      // The end date itself is still covered (inclusive).
      expect(ended.coversDate(today), isTrue);
      // The day after is not.
      expect(ended.coversDate(DateTime(2026, 10, 2)), isFalse);
    });
  });

  group('Day summary expected ⊆ roster invariant', () {
    final today = DateTime(2026, 10, 1); // Thursday
    final roster = [
      _enrollment(id: 'r1', attendanceDays: null), // every day
      _enrollment(id: 'r2', attendanceDays: {1, 3, 5}), // Thu excluded
      _enrollment(id: 'r3', attendanceDays: {4}), // Thu only
      _enrollment(
          id: 'r4',
          enrolledFrom: DateTime(2027, 1, 1)), // future, not in roster
    ];

    test('Only enrollments that cover the date are in the roster for '
        'that date', () {
      final covering = roster.where((e) => e.coversDate(today)).toList();
      expect(covering.map((e) => e.id).toList(),
          equals(['r1', 'r2', 'r3']));
    });

    test('expected is a strict subset: r2 drops out on Thu', () {
      final covering = roster.where((e) => e.coversDate(today)).toList();
      final expected =
          covering.where((e) => e.isExpectedForDate(today)).toList();
      // r1 and r3 are expected; r2 isn't.
      expect(expected.map((e) => e.id).toSet(), {'r1', 'r3'});
      // Still, r2 must stay in the roster so the UI can show it with
      // a muted "Nu participă azi" chip + admin menu.
      expect(covering.map((e) => e.id).toSet(), {'r1', 'r2', 'r3'});
    });
  });
}
