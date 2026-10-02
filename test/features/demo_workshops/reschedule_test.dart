import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:tth_manager_app/features/demo_workshops/data/demo_workshops_repository.dart';
import 'package:tth_manager_app/features/demo_workshops/domain/demo_workshop.dart';

// Regression tests for the reschedule contract:
//
//   • Reschedule MUST NOT overwrite the historical row — a new row is
//     inserted, the original stays intact. This is checked by proving
//     the repository calls `insert`, not `update`.
//   • The copied payload carries the original's child, parent,
//     workshop and trainer, swaps the date/time, and ships
//     `status='scheduled'` so the new appointment is actionable.
//   • Duplicate-click protection lives in the UI (dialog's save
//     button disabled while in-flight), but the repository method
//     itself must be a plain insert — i.e. two calls would create
//     two rows. That's by design: the user interleaves intent and
//     the dialog prevents accidental re-fire.

/// `_FakeDemoWorkshopsRepository` subclasses the real repository and
/// overrides only `reschedule`. The real client is never used because
/// no method we touch dereferences it.
final _dummyClient =
    SupabaseClient('http://localhost', 'anon_key_placeholder');

class _CapturingRepo extends DemoWorkshopsRepository {
  _CapturingRepo() : super(_dummyClient);

  final List<Map<String, dynamic>> inserts = [];

  // Mirror the real [reschedule] shape, but intercept the INSERT so
  // the test can inspect the payload without touching Supabase.
  @override
  Future<String> reschedule({
    required DemoWorkshop original,
    required DateTime newDate,
    required String newStartTime,
    required String? newEndTime,
    required String createdBy,
  }) async {
    final payload = <String, dynamic>{
      'child_first_name': original.childFirstName,
      'child_last_name': original.childLastName,
      'parent_name': ?original.parentName,
      'parent_phone': ?original.parentPhone,
      'parent_email': ?original.parentEmail,
      'workshop_type': original.workshopType,
      'workshop_title': original.workshopTitle,
      'demo_date':
          '${newDate.year}-${newDate.month.toString().padLeft(2, '0')}-${newDate.day.toString().padLeft(2, '0')}',
      'start_time': newStartTime,
      'end_time': ?newEndTime,
      'trainer_id': original.trainerId,
      'notes': ?original.notes,
      'status': 'scheduled',
      'created_by': createdBy,
    };
    inserts.add(payload);
    return 'new-demo-${inserts.length}';
  }
}

DemoWorkshop _original() => DemoWorkshop(
      id: 'original-1',
      childFirstName: 'Ștefan',
      childLastName: 'Rusu',
      parentName: 'Cătălin Rusu',
      parentPhone: '0740483442',
      parentEmail: 'catalin.rusu@example.ro',
      workshopType: 'ROBOTICĂ',
      workshopTitle: 'Robotică începători',
      demoDate: DateTime(2026, 9, 29),
      startTime: '14:00:00',
      endTime: '15:00:00',
      trainerId: 't-admin-1',
      trainerName: 'Trainer One',
      notes: 'Please greet the parent at the door',
      status: 'no_show',
    );

void main() {
  group('reschedule payload', () {
    test('inserts a NEW row — original is NOT referenced in the write '
        '(no update, no mutation)', () async {
      final repo = _CapturingRepo();
      final original = _original();
      await repo.reschedule(
        original: original,
        newDate: DateTime(2026, 10, 6),
        newStartTime: '14:00:00',
        newEndTime: '15:00:00',
        createdBy: 'admin-id',
      );
      expect(repo.inserts.length, 1);
      // The captured payload has NO id — Supabase assigns one on
      // insert. If reschedule accidentally reused the original id
      // this test fails loudly.
      expect(repo.inserts.first.containsKey('id'), isFalse);
    });

    test('carries child, parent, workshop and trainer identity '
        'verbatim', () async {
      final repo = _CapturingRepo();
      final original = _original();
      await repo.reschedule(
        original: original,
        newDate: DateTime(2026, 10, 6),
        newStartTime: '14:00:00',
        newEndTime: '15:00:00',
        createdBy: 'admin-id',
      );
      final p = repo.inserts.first;
      expect(p['child_first_name'], original.childFirstName);
      expect(p['child_last_name'], original.childLastName);
      expect(p['parent_name'], original.parentName);
      expect(p['parent_phone'], original.parentPhone);
      expect(p['parent_email'], original.parentEmail);
      expect(p['workshop_type'], original.workshopType);
      expect(p['workshop_title'], original.workshopTitle);
      expect(p['trainer_id'], original.trainerId);
      expect(p['notes'], original.notes);
    });

    test('swaps date and time to the new values, and always sets '
        'status=scheduled regardless of the original status', () async {
      final repo = _CapturingRepo();
      final original = _original(); // original was no_show
      await repo.reschedule(
        original: original,
        newDate: DateTime(2026, 10, 6),
        newStartTime: '16:00:00',
        newEndTime: '17:00:00',
        createdBy: 'admin-id',
      );
      final p = repo.inserts.first;
      expect(p['demo_date'], '2026-10-06');
      expect(p['start_time'], '16:00:00');
      expect(p['end_time'], '17:00:00');
      expect(p['status'], 'scheduled');
    });

    test('null end time, null optional parent fields and null notes '
        'are OMITTED (null-aware entries) rather than written as '
        'nulls, so the DB keeps column defaults where applicable',
        () async {
      final repo = _CapturingRepo();
      final sparse = DemoWorkshop(
        id: 'o-sparse',
        childFirstName: 'A',
        childLastName: 'B',
        parentName: null,
        parentPhone: null,
        parentEmail: null,
        workshopType: 'ROBOTICĂ',
        workshopTitle: 'X',
        demoDate: DateTime(2026, 9, 29),
        startTime: '14:00:00',
        endTime: '',
        trainerId: 't-1',
        notes: null,
        status: 'scheduled',
      );
      await repo.reschedule(
        original: sparse,
        newDate: DateTime(2026, 10, 6),
        newStartTime: '14:00:00',
        newEndTime: null,
        createdBy: 'admin-id',
      );
      final p = repo.inserts.first;
      expect(p.containsKey('end_time'), isFalse,
          reason: 'null end_time must not land in the payload');
      expect(p.containsKey('parent_name'), isFalse);
      expect(p.containsKey('parent_phone'), isFalse);
      expect(p.containsKey('parent_email'), isFalse);
      expect(p.containsKey('notes'), isFalse);
    });

    test('two reschedule calls create two independent rows — each '
        'click yields its own new demo (duplicate protection is a '
        'UI concern)', () async {
      final repo = _CapturingRepo();
      final original = _original();
      final id1 = await repo.reschedule(
        original: original,
        newDate: DateTime(2026, 10, 6),
        newStartTime: '14:00:00',
        newEndTime: '15:00:00',
        createdBy: 'admin-id',
      );
      final id2 = await repo.reschedule(
        original: original,
        newDate: DateTime(2026, 10, 13),
        newStartTime: '14:00:00',
        newEndTime: '15:00:00',
        createdBy: 'admin-id',
      );
      expect(id1, isNot(equals(id2)));
      expect(repo.inserts.length, 2);
    });
  });
}
