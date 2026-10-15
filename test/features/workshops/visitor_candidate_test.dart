import 'package:flutter_test/flutter_test.dart';

import 'package:tth_manager_app/features/workshops/domain/visitor_candidate.dart';
import 'package:tth_manager_app/features/workshops/domain/workshop_detail_row.dart';

void main() {
  group('VisitorCandidate', () {
    test('fullName falls back to "(fără nume)" when both names are empty',
        () {
      const c = VisitorCandidate(
        childId: 'c1',
        firstName: '',
        lastName: '',
        enrollments: [],
      );
      expect(c.fullName, '(fără nume)');
    });

    test('needsEnrollmentChoice toggles with enrollment count', () {
      const one = VisitorCandidate(
        childId: 'c1',
        firstName: 'Ana',
        lastName: 'Pop',
        enrollments: [
          VisitorCandidateEnrollment(
            seriesId: 's1',
            seriesTitle: 'Robotica',
            dayOfWeek: 'MARTI',
            startTime: '16:00',
          ),
        ],
      );
      expect(one.needsEnrollmentChoice, isFalse);

      const two = VisitorCandidate(
        childId: 'c1',
        firstName: 'Ana',
        lastName: 'Pop',
        enrollments: [
          VisitorCandidateEnrollment(
            seriesId: 's1',
            seriesTitle: 'Robotica',
            dayOfWeek: 'MARTI',
            startTime: '16:00',
          ),
          VisitorCandidateEnrollment(
            seriesId: 's2',
            seriesTitle: 'Robotica',
            dayOfWeek: 'JOI',
            startTime: '17:00',
          ),
        ],
      );
      expect(two.needsEnrollmentChoice, isTrue);
    });

    test('regularGroupLabel maps Romanian day codes to display', () {
      const enr = VisitorCandidateEnrollment(
        seriesId: 's',
        seriesTitle: '',
        dayOfWeek: 'MARTI',
        startTime: '16:00',
      );
      expect(enr.regularGroupLabel, 'Marți 16:00');
    });

    test('regularGroupLabel falls back to raw code for unknown day', () {
      const enr = VisitorCandidateEnrollment(
        seriesId: 's',
        seriesTitle: '',
        dayOfWeek: 'UNKNOWN',
        startTime: '09:30',
      );
      expect(enr.regularGroupLabel, 'UNKNOWN 09:30');
    });
  });

  group('WorkshopDetailRow visitor-awareness', () {
    final base = WorkshopDetailRow(
      workshopId: 'w1',
      title: 'Robotica Marți 16:00',
      workshopType: 'Robotica',
      workshopDate: DateTime(2026, 10, 20),
      dayOfWeek: 'MARTI',
      startTime: '16:00',
      endTime: '17:30',
      trainerId: 't1',
      seriesId: 's-tue',
      childId: 'c1',
      childFirstName: 'Andrei',
      childLastName: 'Popescu',
      attendanceStatus: 'present',
    );

    test('regular enrolled row is NOT a visitor', () {
      expect(base.isVisitor, isFalse);
    });

    test('row with credited_series_id IS a visitor', () {
      final v = WorkshopDetailRow(
        workshopId: base.workshopId,
        title: base.title,
        workshopType: base.workshopType,
        workshopDate: base.workshopDate,
        dayOfWeek: base.dayOfWeek,
        startTime: base.startTime,
        endTime: base.endTime,
        trainerId: base.trainerId,
        seriesId: 's-mon',
        childId: 'c1',
        childFirstName: 'Andrei',
        childLastName: 'Popescu',
        attendanceStatus: 'present',
        creditedSeriesId: 's-tue',
        visitorRegularDayOfWeek: 'MARTI',
        visitorRegularStartTime: '16:00',
      );
      expect(v.isVisitor, isTrue);
    });

    test('fromMap round-trips credited_series_id + visitor metadata', () {
      final r = WorkshopDetailRow.fromMap({
        'workshop_id': 'w1',
        'title': 't',
        'workshop_type': 'Robotica',
        'workshop_date': '2026-10-20',
        'day_of_week': 'MARTI',
        'start_time': '16:00',
        'end_time': '17:30',
        'trainer_id': 't1',
        'child_id': 'c1',
        'credited_series_id': 's-x',
        'visitor_regular_day_of_week': 'LUNI',
        'visitor_regular_start_time': '16:00',
        'visitor_regular_series_title': 'Robotica Luni 16:00',
      });
      expect(r.isVisitor, isTrue);
      expect(r.creditedSeriesId, 's-x');
      expect(r.visitorRegularDayOfWeek, 'LUNI');
      expect(r.visitorRegularStartTime, '16:00');
      expect(r.visitorRegularSeriesTitle, 'Robotica Luni 16:00');
    });

    test('fromMap without credited_series_id yields a non-visitor row', () {
      final r = WorkshopDetailRow.fromMap({
        'workshop_id': 'w1',
        'title': 't',
        'workshop_type': 'Robotica',
        'workshop_date': '2026-10-20',
        'day_of_week': 'MARTI',
        'start_time': '16:00',
        'end_time': '17:30',
        'trainer_id': 't1',
        'child_id': 'c1',
      });
      expect(r.isVisitor, isFalse);
      expect(r.creditedSeriesId, isNull);
    });
  });
}
