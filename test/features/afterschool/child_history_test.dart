import 'package:flutter_test/flutter_test.dart';

import 'package:tth_manager_app/features/afterschool/domain/afterschool_child_history.dart';
import 'package:tth_manager_app/features/afterschool/domain/afterschool_enrollment.dart';
import 'package:tth_manager_app/features/afterschool/domain/afterschool_program.dart';

const _programId = 'cccccccc-0000-0000-0000-000000000001';
const _childId = 'a0000000-0000-0000-0000-00000000000a';

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

AfterschoolEnrollment _enrollment({
  required String id,
  DateTime? enrolledFrom,
  DateTime? enrolledUntil,
}) =>
    AfterschoolEnrollment(
      id: id,
      childId: _childId,
      programId: _programId,
      enrolledFrom: enrolledFrom ?? DateTime(2026, 1, 1),
      enrolledUntil: enrolledUntil,
      isActive: enrolledUntil == null,
      createdAt: DateTime(2020, 1, 1),
      updatedAt: DateTime(2020, 1, 1),
    );

void main() {
  group('buildAfterschoolChildHistory (attendance-only)', () {
    final today = DateTime(2026, 10, 1);

    test('historical months covered by enrollment appear', () {
      final enr = _enrollment(
        id: 'enr-1',
        enrolledFrom: DateTime(2026, 6, 1),
      );
      final blocks = buildAfterschoolChildHistory(
        enrollments: [enr],
        allPrograms: [_program()],
        today: today,
      );
      expect(blocks, hasLength(1));
      final entries = blocks.first.entries;
      // Months: June, July, August, September, October (5 months)
      expect(entries, hasLength(5));
      // Newest first.
      expect(entries[0].year, 2026);
      expect(entries[0].month, 10);
      // All months in the covered range appear.
      final months = entries.map((e) => e.month).toSet();
      expect(months, {6, 7, 8, 9, 10});
    });

    test('month outside enrollment window does NOT appear', () {
      final enr = _enrollment(
        id: 'enr-1',
        enrolledFrom: DateTime(2026, 6, 1),
        enrolledUntil: DateTime(2026, 8, 31),
      );
      final blocks = buildAfterschoolChildHistory(
        enrollments: [enr],
        allPrograms: [_program()],
        today: today,
      );
      expect(blocks, hasLength(1));
      final entries = blocks.first.entries;
      // Expected months: Jun, Jul, Aug (enrolled closed Aug 31)
      expect(entries, hasLength(3));
      expect(entries.every((e) => e.month >= 6 && e.month <= 8), isTrue);
      expect(entries.every((e) => e.year == 2026), isTrue);
    });

    test('future months are never in history', () {
      final enr = _enrollment(
        id: 'enr-1',
        enrolledFrom: DateTime(2026, 10, 1),
      );
      final blocks = buildAfterschoolChildHistory(
        enrollments: [enr],
        allPrograms: [_program()],
        today: today,
      );
      expect(blocks, hasLength(1));
      final entries = blocks.first.entries;
      // Only current month (October).
      expect(entries, hasLength(1));
      expect(entries.first.month, 10);
    });

    test('ended enrollment with gaps between re-enrol excludes gap months', () {
      // Enrolment 1: Jan..Mar 2026. Gap Apr-May. Enrolment 2: Jun..open.
      final e1 = _enrollment(
        id: 'enr-1',
        enrolledFrom: DateTime(2026, 1, 1),
        enrolledUntil: DateTime(2026, 3, 31),
      );
      final e2 = _enrollment(
        id: 'enr-2',
        enrolledFrom: DateTime(2026, 6, 1),
      );
      final blocks = buildAfterschoolChildHistory(
        enrollments: [e1, e2],
        allPrograms: [_program()],
        today: today,
      );
      final months = blocks.first.entries.map((e) => e.month).toSet();
      // Months 1,2,3,6,7,8,9,10 → 8 total. 4 and 5 excluded.
      expect(months.contains(4), isFalse);
      expect(months.contains(5), isFalse);
      expect(months.contains(1), isTrue);
      expect(months.contains(6), isTrue);
      expect(months.contains(10), isTrue);
    });
  });
}
