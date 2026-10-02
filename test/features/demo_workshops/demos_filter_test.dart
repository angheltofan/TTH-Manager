import 'package:flutter_test/flutter_test.dart';

import 'package:tth_manager_app/features/demo_workshops/domain/demo_workshop.dart';
import 'package:tth_manager_app/features/demo_workshops/presentation/demos_page.dart';

// Regression tests for the Demos list page's semantic contract — the
// bits a user feels but the UI can't verify by itself. Three concerns:
//
//   1. The row's status pill maps correctly across (lifecycle status
//      × past/today/future). This is the only place the UI invents
//      labels on top of the DB enum ("Nemarcat" when a past demo has
//      no mark; "Programat" for a future scheduled one).
//   2. The search filter accepts whole-name typing, partial name,
//      parent name, phone (with and without common separators) and
//      email. Phone is normalised to digits so "0740 483 442" matches
//      "0740483442".
//   3. Historical demos stay visible — covered implicitly by (1):
//      a past demo in any status still produces a label and never
//      "disappears" from the row.

DemoWorkshop _demo({
  required DateTime date,
  String status = 'scheduled',
  String firstName = 'Ștefan',
  String lastName = 'Rusu',
  String? parentName,
  String? parentPhone,
  String? parentEmail,
}) =>
    DemoWorkshop(
      id: 'd-${date.toIso8601String()}-$status-$firstName',
      childFirstName: firstName,
      childLastName: lastName,
      parentName: parentName,
      parentPhone: parentPhone,
      parentEmail: parentEmail,
      workshopType: 'ROBOTICĂ',
      workshopTitle: 'Robotică începători',
      demoDate: date,
      startTime: '14:00:00',
      endTime: '15:00:00',
      trainerId: 't-1',
      trainerName: 'Trainer Test',
      status: status,
    );

void main() {
  final today = DateTime(2026, 10, 2);
  final yesterday = DateTime(2026, 10, 1);
  final tomorrow = DateTime(2026, 10, 3);

  group('row semantics: status pill label × lifecycle', () {
    test('future scheduled demo → "Programat"', () {
      final d = _demo(date: tomorrow, status: 'scheduled');
      final (label, _) = demoRowSemanticsForTest(d, today);
      expect(label, 'Programat');
    });

    test('today scheduled, unmarked → "Astăzi"', () {
      final d = _demo(date: today, status: 'scheduled');
      final (label, _) = demoRowSemanticsForTest(d, today);
      expect(label, 'Astăzi');
    });

    test('past scheduled, unmarked → "Nemarcat" (must stay visible '
        'in history, not disappear)', () {
      final d = _demo(date: yesterday, status: 'scheduled');
      final (label, _) = demoRowSemanticsForTest(d, today);
      expect(label, 'Nemarcat');
    });

    test('completed (any date) → "Prezent"', () {
      final d = _demo(date: yesterday, status: 'completed');
      final (label, _) = demoRowSemanticsForTest(d, today);
      expect(label, 'Prezent');
    });

    test('no_show (any date) → "Absent"', () {
      final d = _demo(date: yesterday, status: 'no_show');
      final (label, _) = demoRowSemanticsForTest(d, today);
      expect(label, 'Absent');
    });

    test('converted (any date) → "Înscris"', () {
      final d = _demo(date: today, status: 'converted');
      final (label, _) = demoRowSemanticsForTest(d, today);
      expect(label, 'Înscris');
    });

    test('cancelled (any date) → "Anulat"', () {
      final d = _demo(date: tomorrow, status: 'cancelled');
      final (label, _) = demoRowSemanticsForTest(d, today);
      expect(label, 'Anulat');
    });
  });

  group('search filter', () {
    final demos = [
      _demo(
          date: today,
          firstName: 'Ștefan',
          lastName: 'Rusu',
          parentName: 'Cătălin Rusu',
          parentPhone: '0740 483 442',
          parentEmail: 'catalin.rusu@example.ro'),
      _demo(
          date: tomorrow,
          firstName: 'Maria',
          lastName: 'Popescu',
          parentName: 'Ana Popescu',
          parentPhone: '0722 100 200',
          parentEmail: 'ana@example.ro'),
      _demo(
          date: yesterday,
          firstName: 'Andrei',
          lastName: 'Ionescu',
          parentName: null,
          parentPhone: '0745555555',
          parentEmail: null,
          status: 'completed'),
    ];

    test('empty query returns the full list', () {
      expect(applyDemoSearchForTest(demos, '').length, 3);
      expect(applyDemoSearchForTest(demos, '   ').length, 3);
    });

    test('matches child first name (case-insensitive)', () {
      final r = applyDemoSearchForTest(demos, 'maria');
      expect(r.length, 1);
      expect(r.first.childFirstName, 'Maria');
    });

    test('matches combined "first last" name as the user types it', () {
      final r = applyDemoSearchForTest(demos, 'ștefan rusu');
      expect(r.length, 1);
      expect(r.first.childLastName, 'Rusu');
    });

    test('matches parent name substring', () {
      final r = applyDemoSearchForTest(demos, 'ana');
      // "Ana Popescu" and "Cătălin Rusu" doesn't match; just one.
      expect(r.map((d) => d.childFirstName).toSet(), {'Maria'});
    });

    test('matches phone with the spaces that users type', () {
      final r = applyDemoSearchForTest(demos, '0740 483 442');
      expect(r.length, 1);
      expect(r.first.childFirstName, 'Ștefan');
    });

    test('matches phone when user omits the spaces (digits-only '
        'normalisation)', () {
      final r = applyDemoSearchForTest(demos, '0740483442');
      expect(r.length, 1);
    });

    test('matches partial phone (last 4 digits)', () {
      final r = applyDemoSearchForTest(demos, '5555');
      expect(r.length, 1);
      expect(r.first.childFirstName, 'Andrei');
    });

    test('matches email substring', () {
      final r = applyDemoSearchForTest(demos, 'ana@');
      expect(r.length, 1);
      expect(r.first.childFirstName, 'Maria');
    });

    test('no match returns empty list', () {
      final r = applyDemoSearchForTest(demos, 'xxxxxxxx');
      expect(r, isEmpty);
    });

    test('demo with null parent name/email is still searchable by '
        'child name', () {
      final r = applyDemoSearchForTest(demos, 'Andrei');
      expect(r.length, 1);
      expect(r.first.parentName, isNull);
      expect(r.first.parentEmail, isNull);
    });
  });
}
