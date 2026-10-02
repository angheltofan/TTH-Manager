import 'package:flutter_test/flutter_test.dart';

import 'package:tth_manager_app/features/afterschool/domain/afterschool_attendance.dart';
import 'package:tth_manager_app/features/afterschool/domain/afterschool_enrollment.dart';
import 'package:tth_manager_app/features/afterschool/domain/afterschool_program.dart';
import 'package:tth_manager_app/features/afterschool/domain/afterschool_session.dart';
import 'package:tth_manager_app/features/children/data/child_report_repository.dart';
import 'package:tth_manager_app/features/children/domain/child_activity_report.dart';

// Regression tests for the Child Activity Report domain model, built
// through the pure `assembleChildActivityReport` factory so no
// Supabase client is needed. Cases match the brief's A..J matrix:
//
//   A — child with only workshop activity;
//   B — child with only Afterschool activity;
//   C — child with workshop + Afterschool;
//   D — child with no activity at all;
//   E — Afterschool with past presences and future-scheduled days;
//   F — future-scheduled days do NOT count as absences;
//   G — Afterschool report never carries price/payment fields;
//   H — workshop payment data continues to work;
//   I — Afterschool activity surfaces in the general history;
//   J — merged history is sorted descending by date.

const _childId = 'child-x';
const _programId = 'program-x';

ChildReportChildInfo _childInfo({String name = 'Copil Test'}) =>
    ChildReportChildInfo(
      id: _childId,
      fullName: name,
      parentName: 'Părinte Test',
      parentPhone: '0744 000 000',
    );

AfterschoolProgram _program({
  String id = _programId,
  String name = 'Afterschool Robotică',
  Set<int> daysOfWeek = const {1, 2, 3, 4, 5},
  DateTime? activeFrom,
}) =>
    AfterschoolProgram(
      id: id,
      name: name,
      daysOfWeek: daysOfWeek,
      startTime: '13:00:00',
      endTime: '17:00:00',
      monthlyFee: 1300,
      currency: 'RON',
      activeFrom: activeFrom ?? DateTime(2020, 1, 1),
      isActive: true,
      createdAt: DateTime(2020, 1, 1),
      updatedAt: DateTime(2020, 1, 1),
    );

AfterschoolEnrollment _enrollment({
  String id = 'enr-x',
  String programId = _programId,
  DateTime? enrolledFrom,
  DateTime? enrolledUntil,
  bool isActive = true,
}) =>
    AfterschoolEnrollment(
      id: id,
      childId: _childId,
      programId: programId,
      enrolledFrom: enrolledFrom ?? DateTime(2026, 10, 1),
      enrolledUntil: enrolledUntil,
      isActive: isActive,
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 1),
    );

AfterschoolSession _session(String id, DateTime date,
        {String programId = _programId}) =>
    AfterschoolSession(
      id: id,
      programId: programId,
      sessionDate: date,
      startTime: '13:00:00',
      endTime: '17:00:00',
      createdAt: date,
    );

AfterschoolAttendance _attendance(
    String id, String sessionId, AttendanceStatus status) =>
    AfterschoolAttendance(
      id: id,
      sessionId: sessionId,
      childId: _childId,
      status: status,
      markedAt: DateTime(2026, 10, 2, 14, 0),
      updatedAt: DateTime(2026, 10, 2, 14, 0),
    );

void main() {
  final today = DateTime(2026, 10, 2);
  final generatedAt = DateTime(2026, 10, 2, 10, 0);

  group('A — child with only workshop activity', () {
    test('workshop active list, workshop history and workshop summary '
        'populate; Afterschool fields stay empty', () {
      final r = assembleChildActivityReport(
        childInfo: _childInfo(),
        activeWorkshops: const [
          ChildReportWorkshopInfo(
              title: 'Robotică L2',
              workshopType: 'ROBOTICĂ',
              dayOfWeek: 'Luni',
              startTime: '17:00:00',
              endTime: '18:30:00'),
        ],
        workshopAttendance: const [
          ChildReportAttendanceRow(
              workshopTitle: 'Robotică L2',
              status: 'present'),
          ChildReportAttendanceRow(
              workshopTitle: 'Robotică L2',
              status: 'absent'),
        ],
        payments: const [],
        afsBundle: AfterschoolBundle.empty(),
        childId: _childId,
        today: today,
        generatedAt: generatedAt,
      );
      expect(r.activeWorkshops.length, 1);
      expect(r.activeAfterschoolPrograms, isEmpty);
      expect(r.afterschoolMonths, isEmpty);
      expect(r.summary.hasWorkshopActivity, isTrue);
      expect(r.summary.hasAfterschoolActivity, isFalse);
      expect(r.summary.presentCount, 1);
      expect(r.summary.absentCount, 1);
    });
  });

  group('B — child with only Afterschool activity', () {
    test('active Afterschool program surfaces, monthly breakdown '
        'populates, no workshop fields', () {
      final prog = _program();
      final enr = _enrollment(enrolledFrom: DateTime(2026, 10, 1));
      final s1 = _session('s1', DateTime(2026, 10, 1));
      final s2 = _session('s2', DateTime(2026, 10, 2));
      final r = assembleChildActivityReport(
        childInfo: _childInfo(),
        activeWorkshops: const [],
        workshopAttendance: const [],
        payments: const [],
        afsBundle: AfterschoolBundle(
          enrollments: [enr],
          programsById: {prog.id: prog},
          sessions: [s1, s2],
          attendance: [
            _attendance('a1', 's1', AttendanceStatus.present),
            _attendance('a2', 's2', AttendanceStatus.present),
          ],
        ),
        childId: _childId,
        today: today,
        generatedAt: generatedAt,
      );
      expect(r.activeWorkshops, isEmpty);
      expect(r.activeAfterschoolPrograms.length, 1);
      expect(r.activeAfterschoolPrograms.first.programName,
          'Afterschool Robotică');
      expect(r.activeAfterschoolPrograms.first.daysOfWeekLabel, 'L-V');
      expect(r.activeAfterschoolPrograms.first.startTime, '13:00');
      expect(r.activeAfterschoolPrograms.first.endTime, '17:00');
      expect(r.afterschoolMonths.length, 1);
      final m = r.afterschoolMonths.first;
      expect(m.year, 2026);
      expect(m.month, 10);
      expect(m.present, 2);
      expect(m.absent, 0);
      expect(m.expected, 2);
      expect(m.lastPresenceDate, DateTime(2026, 10, 2));
      expect(r.summary.hasAfterschoolActivity, isTrue);
      expect(r.summary.hasWorkshopActivity, isFalse);
      expect(r.summary.afterschoolPresentCount, 2);
      expect(r.summary.afterschoolProgramsCount, 1);
    });
  });

  group('C — child with workshop + Afterschool', () {
    test('both sections populate; history merges workshop + '
        'afterschool rows in a single list', () {
      final prog = _program();
      final enr = _enrollment(enrolledFrom: DateTime(2026, 10, 1));
      final s1 = _session('s1', DateTime(2026, 10, 1));
      final r = assembleChildActivityReport(
        childInfo: _childInfo(),
        activeWorkshops: const [
          ChildReportWorkshopInfo(
              title: 'Robotică L2',
              workshopType: 'ROBOTICĂ',
              dayOfWeek: 'Luni',
              startTime: '17:00:00',
              endTime: '18:30:00'),
        ],
        workshopAttendance: const [
          ChildReportAttendanceRow(
              workshopTitle: 'Robotică L2',
              workshopType: 'ROBOTICĂ',
              status: 'present'),
        ],
        payments: const [
          ChildReportPaymentRow(status: 'paid', seriesTitle: 'Robotică L2'),
        ],
        afsBundle: AfterschoolBundle(
          enrollments: [enr],
          programsById: {prog.id: prog},
          sessions: [s1],
          attendance: [
            _attendance('a1', 's1', AttendanceStatus.present),
          ],
        ),
        childId: _childId,
        today: today,
        generatedAt: generatedAt,
      );
      expect(r.activeWorkshops.length, 1);
      expect(r.activeAfterschoolPrograms.length, 1);
      expect(r.afterschoolMonths.length, 1);
      // Merged history contains both kinds, distinguishable by type.
      final types =
          r.attendanceRows.map((e) => e.workshopType).toSet();
      expect(types.contains('ROBOTICĂ'), isTrue);
      expect(types.contains('Afterschool'), isTrue);
    });
  });

  group('D — child with no activity at all', () {
    test('every section is empty, summary.hasActivity is false', () {
      final r = assembleChildActivityReport(
        childInfo: _childInfo(),
        activeWorkshops: const [],
        workshopAttendance: const [],
        payments: const [],
        afsBundle: AfterschoolBundle.empty(),
        childId: _childId,
        today: today,
        generatedAt: generatedAt,
      );
      expect(r.activeWorkshops, isEmpty);
      expect(r.activeAfterschoolPrograms, isEmpty);
      expect(r.attendanceRows, isEmpty);
      expect(r.afterschoolMonths, isEmpty);
      expect(r.paymentRows, isEmpty);
      expect(r.summary.hasActivity, isFalse);
    });
  });

  group('E — Afterschool with past presences and future-scheduled '
      'days', () {
    test('monthly breakdown separates present vs plannedFuture', () {
      final prog = _program();
      final enr = _enrollment(enrolledFrom: DateTime(2026, 10, 1));
      // Oct 1 (Thu) and Oct 2 (Fri) are past-or-today (today = Oct 2),
      // with attendance. Oct 5-9 are future weekdays (plannedFuture).
      final sessions = [
        _session('s1', DateTime(2026, 10, 1)),
        _session('s2', DateTime(2026, 10, 2)),
      ];
      final r = assembleChildActivityReport(
        childInfo: _childInfo(),
        activeWorkshops: const [],
        workshopAttendance: const [],
        payments: const [],
        afsBundle: AfterschoolBundle(
          enrollments: [enr],
          programsById: {prog.id: prog},
          sessions: sessions,
          attendance: [
            _attendance('a1', 's1', AttendanceStatus.present),
            _attendance('a2', 's2', AttendanceStatus.present),
          ],
        ),
        childId: _childId,
        today: today,
        generatedAt: generatedAt,
      );
      final m = r.afterschoolMonths.single;
      expect(m.present, 2);
      expect(m.absent, 0);
      // Future weekdays in Oct 2026 after Oct 2: 3..31. Mon-Fri only.
      // Oct 5, 6, 7, 8, 9, 12, 13, 14, 15, 16, 19, 20, 21, 22, 23,
      // 26, 27, 28, 29, 30 → 20 weekdays. plannedFuture must be ≥ 1
      // and must NOT be 0 (we're mid-month).
      expect(m.plannedFuture, greaterThan(0));
    });
  });

  group('F — future-scheduled days are NEVER absences', () {
    test('plannedFuture and absent are independent — a future day '
        'does not inflate absent', () {
      final prog = _program();
      final enr = _enrollment(enrolledFrom: DateTime(2026, 10, 1));
      // No attendance rows at all; the whole month has future days
      // for a child enrolled on Oct 1 with today = Oct 2.
      final r = assembleChildActivityReport(
        childInfo: _childInfo(),
        activeWorkshops: const [],
        workshopAttendance: const [],
        payments: const [],
        afsBundle: AfterschoolBundle(
          enrollments: [enr],
          programsById: {prog.id: prog},
          sessions: const [],
          attendance: const [],
        ),
        childId: _childId,
        today: today,
        generatedAt: generatedAt,
      );
      final m = r.afterschoolMonths.single;
      expect(m.absent, 0,
          reason: 'Future-scheduled days must never count as absences');
      expect(m.plannedFuture, greaterThan(0));
      expect(r.summary.afterschoolAbsentCount, 0);
      expect(r.summary.afterschoolPlannedCount, m.plannedFuture);
    });
  });

  group('G — Afterschool report carries no price/payment fields', () {
    test('ChildReportAfterschoolProgramInfo has no price surface at '
        'the type level', () {
      // Compile-time check: this list of expected fields is the
      // entire surface. Adding `fee` / `price` / `amount` here would
      // break at compile time.
      const info = ChildReportAfterschoolProgramInfo(
        programName: 'X',
        daysOfWeekLabel: 'L-V',
        startTime: '13:00',
        endTime: '17:00',
      );
      expect(info.programName, 'X');
      expect(info.daysOfWeekLabel, 'L-V');
    });

    test('Afterschool-only child → payment rows are empty, PDF '
        'service hides the "Istoric plăți" section via isEmpty',
        () {
      final prog = _program();
      final enr = _enrollment(enrolledFrom: DateTime(2026, 10, 1));
      final r = assembleChildActivityReport(
        childInfo: _childInfo(),
        activeWorkshops: const [],
        workshopAttendance: const [],
        payments: const [],
        afsBundle: AfterschoolBundle(
          enrollments: [enr],
          programsById: {prog.id: prog},
          sessions: const [],
          attendance: const [],
        ),
        childId: _childId,
        today: today,
        generatedAt: generatedAt,
      );
      expect(r.paymentRows, isEmpty);
    });
  });

  group('H — workshop payments still work for mixed children', () {
    test('workshop payment counts flow into the summary and '
        'paymentRows survive the merge', () {
      final r = assembleChildActivityReport(
        childInfo: _childInfo(),
        activeWorkshops: const [],
        workshopAttendance: const [],
        payments: const [
          ChildReportPaymentRow(
              status: 'paid', seriesTitle: 'Robotică L2'),
          ChildReportPaymentRow(
              status: 'overdue', seriesTitle: 'Robotică L2'),
        ],
        afsBundle: AfterschoolBundle.empty(),
        childId: _childId,
        today: today,
        generatedAt: generatedAt,
      );
      expect(r.paymentRows.length, 2);
      expect(r.summary.confirmedPayments, 1);
      expect(r.summary.overduePayments, 1);
    });
  });

  group('I — Afterschool activity surfaces in the general history',
      () {
    test('present/absent Afterschool rows appear in attendanceRows '
        'with workshopType="Afterschool"', () {
      final prog = _program();
      final enr = _enrollment(enrolledFrom: DateTime(2026, 10, 1));
      final s = _session('s1', DateTime(2026, 10, 1));
      final r = assembleChildActivityReport(
        childInfo: _childInfo(),
        activeWorkshops: const [],
        workshopAttendance: const [],
        payments: const [],
        afsBundle: AfterschoolBundle(
          enrollments: [enr],
          programsById: {prog.id: prog},
          sessions: [s],
          attendance: [
            _attendance('a1', 's1', AttendanceStatus.present),
          ],
        ),
        childId: _childId,
        today: today,
        generatedAt: generatedAt,
      );
      expect(r.attendanceRows.length, 1);
      expect(r.attendanceRows.first.workshopType, 'Afterschool');
      expect(r.attendanceRows.first.workshopTitle,
          'Afterschool Robotică');
      expect(r.attendanceRows.first.status, 'present');
    });
  });

  group('J — merged history is sorted newest-first', () {
    test('workshop and Afterschool rows interleave correctly by '
        'date descending', () {
      final prog = _program();
      final enr = _enrollment(enrolledFrom: DateTime(2026, 9, 1));
      final sessions = [
        _session('s1', DateTime(2026, 9, 15)),
        _session('s2', DateTime(2026, 10, 1)),
      ];
      final r = assembleChildActivityReport(
        childInfo: _childInfo(),
        activeWorkshops: const [],
        workshopAttendance: [
          ChildReportAttendanceRow(
              workshopTitle: 'Robotică',
              workshopType: 'ROBOTICĂ',
              date: DateTime(2026, 9, 20),
              status: 'present'),
          ChildReportAttendanceRow(
              workshopTitle: 'Robotică',
              workshopType: 'ROBOTICĂ',
              date: DateTime(2026, 10, 2),
              status: 'absent'),
        ],
        payments: const [],
        afsBundle: AfterschoolBundle(
          enrollments: [enr],
          programsById: {prog.id: prog},
          sessions: sessions,
          attendance: [
            _attendance('a1', 's1', AttendanceStatus.present),
            _attendance('a2', 's2', AttendanceStatus.absent),
          ],
        ),
        childId: _childId,
        today: today,
        generatedAt: generatedAt,
      );
      final dates = r.attendanceRows.map((e) => e.date).toList();
      // Must be strictly non-increasing.
      for (var i = 1; i < dates.length; i++) {
        final prev = dates[i - 1] ?? DateTime(0);
        final cur = dates[i] ?? DateTime(0);
        expect(prev.compareTo(cur), greaterThanOrEqualTo(0));
      }
      // First row: 2026-10-02 (newest).
      expect(r.attendanceRows.first.date, DateTime(2026, 10, 2));
    });

    test('also newest-month-first in afterschoolMonths', () {
      final prog = _program();
      // Enrolled from Jun 1 2026 through today (Oct 2) with a few
      // past-month sessions.
      final enr = _enrollment(enrolledFrom: DateTime(2026, 6, 1));
      final sessions = [
        _session('s1', DateTime(2026, 6, 15)),
        _session('s2', DateTime(2026, 9, 10)),
        _session('s3', DateTime(2026, 10, 1)),
      ];
      final r = assembleChildActivityReport(
        childInfo: _childInfo(),
        activeWorkshops: const [],
        workshopAttendance: const [],
        payments: const [],
        afsBundle: AfterschoolBundle(
          enrollments: [enr],
          programsById: {prog.id: prog},
          sessions: sessions,
          attendance: [
            _attendance('a1', 's1', AttendanceStatus.present),
            _attendance('a2', 's2', AttendanceStatus.present),
            _attendance('a3', 's3', AttendanceStatus.present),
          ],
        ),
        childId: _childId,
        today: today,
        generatedAt: generatedAt,
      );
      final months = r.afterschoolMonths
          .map((e) => DateTime(e.year, e.month, 1))
          .toList();
      for (var i = 1; i < months.length; i++) {
        expect(months[i - 1].compareTo(months[i]),
            greaterThanOrEqualTo(0));
      }
      expect(months.first, DateTime(2026, 10, 1));
    });
  });
}
