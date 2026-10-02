import 'package:flutter_test/flutter_test.dart';

import 'package:tth_manager_app/features/demo_workshops/providers/demo_workshops_providers.dart';

// Pure-function regression for the Demo-uri bucket classifier. The
// mutation paths (status change, reschedule, convert) rely on
// [demoBucketFor] to decide which single tab provider to invalidate
// after a write instead of broadcasting the invalidation to all
// four. If this classifier regresses, the perceived-slowness fix
// regresses with it — hence a dedicated test.
void main() {
  group('demoBucketFor — bucket classification', () {
    final today = DateTime(2026, 10, 2);

    test('a date strictly after today → upcoming', () {
      expect(demoBucketFor(DateTime(2026, 10, 3), today),
          DemoBucket.upcoming);
      expect(demoBucketFor(DateTime(2027, 1, 1), today),
          DemoBucket.upcoming);
    });

    test('today → today (hour/minute components are ignored)', () {
      expect(demoBucketFor(DateTime(2026, 10, 2, 23, 59, 59), today),
          DemoBucket.today);
      expect(demoBucketFor(DateTime(2026, 10, 2, 0, 0, 0), today),
          DemoBucket.today);
    });

    test('a date strictly before today → history', () {
      expect(demoBucketFor(DateTime(2026, 10, 1), today),
          DemoBucket.history);
      expect(demoBucketFor(DateTime(2020, 1, 1), today),
          DemoBucket.history);
    });

    test('tomorrow at 00:00:00 is upcoming (not today)', () {
      expect(demoBucketFor(DateTime(2026, 10, 3, 0, 0, 0), today),
          DemoBucket.upcoming);
    });

    test('yesterday at 23:59:59 is history (not today)', () {
      expect(demoBucketFor(DateTime(2026, 10, 1, 23, 59, 59), today),
          DemoBucket.history);
    });
  });
}
