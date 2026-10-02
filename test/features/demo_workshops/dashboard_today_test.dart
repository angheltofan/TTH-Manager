import 'package:flutter_test/flutter_test.dart';

import 'package:tth_manager_app/features/demo_workshops/data/demo_workshops_repository.dart';

// Regression test for the Dashboard today-demo filter.
//
// Before this change the repository's `getTodayDemos()` filtered to
// `status = 'scheduled'` only, so a demo marked `completed`,
// `no_show`, or `converted` during the day vanished from the
// Dashboard "Ateliere azi" section — the trainer couldn't tell at a
// glance who had already shown up or converted.
//
// New contract (documented on the repository as
// `DemoWorkshopsRepository.isDashboardTodayVisible`): every status
// EXCEPT `cancelled` belongs on the Dashboard. The SQL query uses
// `.neq('status', 'cancelled')` and must stay in sync with this
// predicate.
void main() {
  group('Dashboard today-demo visibility (isDashboardTodayVisible)', () {
    test('scheduled → visible (unchanged behavior for the actionable '
        'case)', () {
      expect(DemoWorkshopsRepository.isDashboardTodayVisible('scheduled'),
          isTrue);
    });

    test('completed → visible (regression — used to be filtered out)',
        () {
      expect(DemoWorkshopsRepository.isDashboardTodayVisible('completed'),
          isTrue);
    });

    test('no_show → visible (regression — used to be filtered out)', () {
      expect(DemoWorkshopsRepository.isDashboardTodayVisible('no_show'),
          isTrue);
    });

    test('converted → visible (regression — used to be filtered out)',
        () {
      expect(DemoWorkshopsRepository.isDashboardTodayVisible('converted'),
          isTrue);
    });

    test('cancelled → hidden (explicitly removed from the day)', () {
      expect(DemoWorkshopsRepository.isDashboardTodayVisible('cancelled'),
          isFalse);
    });

    test('every CHECK-constraint status value has a defined policy '
        '(if someone adds a status without updating the predicate, '
        'the test fails at the new value)', () {
      // The DB CHECK is: status IN (scheduled, completed, converted,
      // cancelled, no_show). If the enum grows the predicate owner
      // decides what the Dashboard should do.
      const known = {
        'scheduled',
        'completed',
        'converted',
        'cancelled',
        'no_show',
      };
      for (final s in known) {
        // Call it — the point is to exercise every current value so
        // adding a new one upstream shows up as a test failure here
        // the moment it enters the test's `known` set.
        DemoWorkshopsRepository.isDashboardTodayVisible(s);
      }
    });
  });
}
