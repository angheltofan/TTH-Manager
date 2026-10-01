import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/afterschool_enrollment.dart';

/// Data layer for `afterschool_enrollments`.
///
/// Enrollment management is admin-only (matches
/// workshop_enrollments' pattern). Historical rows are never deleted —
/// closing an enrollment sets `enrolled_until` and `is_active = false`.
class AfterschoolEnrollmentsRepository {
  const AfterschoolEnrollmentsRepository(this._client);

  final SupabaseClient _client;

  static const _selectCols = '''
id, child_id, program_id, enrolled_from, enrolled_until,
custom_monthly_fee, attendance_days, expected_arrival_time,
is_active, notes, enrolled_by, created_at, updated_at
''';

  Future<List<AfterschoolEnrollment>> fetchForChild(String childId) async {
    final data = await _client
        .from('afterschool_enrollments')
        .select(_selectCols)
        .eq('child_id', childId)
        .order('enrolled_from', ascending: false);
    return (data as List)
        .map((e) =>
            AfterschoolEnrollment.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// All currently-active enrollments, across all programs. Used by
  /// the global children list to render Afterschool badges alongside
  /// workshop badges on each child row.
  Future<List<AfterschoolEnrollment>> fetchAllActive() async {
    final data = await _client
        .from('afterschool_enrollments')
        .select(_selectCols)
        .eq('is_active', true)
        .filter('enrolled_until', 'is', null);
    return (data as List)
        .map((e) =>
            AfterschoolEnrollment.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<AfterschoolEnrollment>> fetchActiveForProgram(
      String programId) async {
    final data = await _client
        .from('afterschool_enrollments')
        .select(_selectCols)
        .eq('program_id', programId)
        .eq('is_active', true)
        .filter('enrolled_until', 'is', null);
    return (data as List)
        .map((e) =>
            AfterschoolEnrollment.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetches all enrollments (any child) that cover `date` in the
  /// given program. Used by the "Today" tab to determine which
  /// children are expected to attend a session on that date.
  Future<List<AfterschoolEnrollment>> fetchCoveringDate({
    required String programId,
    required DateTime date,
  }) async {
    final iso = _dateOnly(date);
    final data = await _client
        .from('afterschool_enrollments')
        .select(_selectCols)
        .eq('program_id', programId)
        .eq('is_active', true)
        .lte('enrolled_from', iso)
        .or('enrolled_until.is.null,enrolled_until.gte.$iso');
    return (data as List)
        .map((e) =>
            AfterschoolEnrollment.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetches every enrollment that overlaps ANY day of the given
  /// (year, month) — i.e. `enrolled_from ≤ month_end AND
  /// (enrolled_until IS NULL OR enrolled_until ≥ month_start)`.
  ///
  /// Used by the Phase 4 monthly-payments snapshot: a child is billed
  /// for the month as long as their enrollment overlapped the month
  /// AT ALL (no automatic proration).
  Future<List<AfterschoolEnrollment>> fetchCoveringMonth({
    required String programId,
    required int year,
    required int month,
  }) async {
    final monthStart = DateTime(year, month, 1);
    final monthEnd = DateTime(year, month + 1, 0);
    final startIso = _dateOnly(monthStart);
    final endIso = _dateOnly(monthEnd);
    final data = await _client
        .from('afterschool_enrollments')
        .select(_selectCols)
        .eq('program_id', programId)
        .eq('is_active', true)
        .lte('enrolled_from', endIso)
        .or('enrolled_until.is.null,enrolled_until.gte.$startIso');
    return (data as List)
        .map((e) =>
            AfterschoolEnrollment.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Creates a new enrollment. Admin-only. Partial unique index
  /// `uq_afs_enr_active` prevents two active NULL-until rows per
  /// (child, program) simultaneously; a re-enrollment is legal after
  /// the previous row is closed with `endEnrollment`.
  ///
  /// [attendanceDays] restricts the child to specific ISO weekdays
  /// (1 = Mon .. 7 = Sun) inside the program's `days_of_week`. `null`
  /// means "follows every program day". The DB trigger
  /// `tg_afs_enr_attendance_days_subset` enforces the subset rule
  /// against the program's schedule — callers should validate
  /// client-side too, using [validateAttendanceDaysAgainstProgram],
  /// to surface a nicer error message.
  ///
  /// [expectedArrivalTime] is informational only (`HH:mm` or
  /// `HH:mm:ss`). It never changes attendance semantics.
  Future<AfterschoolEnrollment> create({
    required bool isAdmin,
    required String childId,
    required String programId,
    required DateTime enrolledFrom,
    Set<int>? attendanceDays,
    String? expectedArrivalTime,
    String? notes,
    required String enrolledBy,
  }) async {
    if (!isAdmin) {
      throw StateError(
          'Only admins may enroll a child in an Afterschool program');
    }
    _validateAttendanceDaysShape(attendanceDays);
    final payload = <String, dynamic>{
      'child_id': childId,
      'program_id': programId,
      'enrolled_from': _dateOnly(enrolledFrom),
      if (attendanceDays != null)
        'attendance_days': (attendanceDays.toList()..sort()),
      if (expectedArrivalTime != null && expectedArrivalTime.trim().isNotEmpty)
        'expected_arrival_time': expectedArrivalTime.trim(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      'enrolled_by': enrolledBy,
      'is_active': true,
    };
    final inserted = await _client
        .from('afterschool_enrollments')
        .insert(payload)
        .select(_selectCols)
        .single();
    return AfterschoolEnrollment.fromMap(inserted);
  }

  /// Updates the per-child schedule. `attendanceDays = null` clears
  /// the override (child follows every program day). Admin-only. The
  /// DB trigger validates against the program's `days_of_week`.
  Future<void> updateAttendanceDays({
    required bool isAdmin,
    required String enrollmentId,
    required Set<int>? attendanceDays,
  }) async {
    if (!isAdmin) {
      throw StateError('Only admins may change an enrollment schedule');
    }
    _validateAttendanceDaysShape(attendanceDays);
    await _client.from('afterschool_enrollments').update({
      'attendance_days':
          attendanceDays == null ? null : (attendanceDays.toList()..sort()),
    }).eq('id', enrollmentId);
  }

  /// Updates the informational arrival time (or clears it with
  /// `expectedArrivalTime = null`). Admin-only.
  Future<void> updateExpectedArrivalTime({
    required bool isAdmin,
    required String enrollmentId,
    required String? expectedArrivalTime,
  }) async {
    if (!isAdmin) {
      throw StateError('Only admins may change an enrollment arrival time');
    }
    await _client.from('afterschool_enrollments').update({
      'expected_arrival_time':
          (expectedArrivalTime == null || expectedArrivalTime.trim().isEmpty)
              ? null
              : expectedArrivalTime.trim(),
    }).eq('id', enrollmentId);
  }

  /// Client-side sanity check for the shape of `attendanceDays` before
  /// sending it to the server. Mirrors the DB CHECK constraint. The
  /// subset-against-program check is enforced server-side by the
  /// trigger (this method deliberately does not fetch the program to
  /// avoid an extra round-trip; use
  /// [validateAttendanceDaysAgainstProgram] when you already have the
  /// program in hand).
  static void _validateAttendanceDaysShape(Set<int>? attendanceDays) {
    if (attendanceDays == null) return;
    if (attendanceDays.isEmpty) {
      throw ArgumentError.value(attendanceDays, 'attendanceDays',
          'must be null or a non-empty subset of program.daysOfWeek');
    }
    for (final d in attendanceDays) {
      if (d < 1 || d > 7) {
        throw ArgumentError.value(attendanceDays, 'attendanceDays',
            'ISO weekday out of range (expected 1..7)');
      }
    }
  }

  /// Optional client-side gate that mirrors the DB trigger and returns
  /// a nicer error before the round-trip. Call this from the enrollment
  /// form when the program is already loaded.
  static void validateAttendanceDaysAgainstProgram({
    required Set<int>? attendanceDays,
    required Set<int> programDaysOfWeek,
  }) {
    _validateAttendanceDaysShape(attendanceDays);
    if (attendanceDays == null) return;
    if (!attendanceDays.every(programDaysOfWeek.contains)) {
      throw ArgumentError.value(attendanceDays, 'attendanceDays',
          'must be a subset of program.daysOfWeek $programDaysOfWeek');
    }
  }

  /// Counts currently-active enrollments for a program (no `enrolled_until`,
  /// `is_active = true`). Used by the UI to display "N / capacity"
  /// before opening the enrollment dialog. Uses the same id-only
  /// projection pattern as the parent dashboard repository (see the
  /// note there on why `.count()` is deliberately avoided).
  Future<int> countActiveForProgram(String programId) async {
    final data = await _client
        .from('afterschool_enrollments')
        .select('id')
        .eq('program_id', programId)
        .eq('is_active', true)
        .filter('enrolled_until', 'is', null);
    return (data as List).length;
  }

  /// Ends an enrollment on [until] (inclusive) — sets `enrolled_until`
  /// and flips `is_active = false`. The row is preserved so the
  /// historical period stays reconstructible. Admin-only.
  Future<void> endEnrollment({
    required bool isAdmin,
    required String enrollmentId,
    required DateTime until,
  }) async {
    if (!isAdmin) {
      throw StateError('Only admins may end an enrollment');
    }
    await _client.from('afterschool_enrollments').update({
      'enrolled_until': _dateOnly(until),
      'is_active': false,
    }).eq('id', enrollmentId);
  }

  /// Hard-deletes an enrollment. Reserved for admin correcting an
  /// erroneous insert BEFORE any related payment is recorded. The
  /// FK from `afterschool_monthly_payments.child_id → children.id`
  /// does not cascade here — an enrollment can be deleted while
  /// payments survive. Use with care.
  Future<void> delete({
    required bool isAdmin,
    required String enrollmentId,
  }) async {
    if (!isAdmin) {
      throw StateError('Only admins may delete an enrollment');
    }
    await _client
        .from('afterschool_enrollments')
        .delete()
        .eq('id', enrollmentId);
  }

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
