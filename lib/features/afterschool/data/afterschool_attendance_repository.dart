import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/afterschool_attendance.dart';

/// Data layer for `afterschool_attendance`.
///
/// Staff can INSERT/UPDATE (matches Q3: admin + trainer may mark
/// attendance). Only admin can DELETE. UNMARKED = no row.
class AfterschoolAttendanceRepository {
  const AfterschoolAttendanceRepository(this._client);

  final SupabaseClient _client;

  static const _selectCols = '''
id, session_id, child_id, status, observation,
marked_at, marked_by, updated_at
''';

  /// All attendance rows for a single session (used by the "Today"
  /// tab and by any per-day inspector). Absent children have no row.
  Future<List<AfterschoolAttendance>> fetchForSession(
      String sessionId) async {
    final data = await _client
        .from('afterschool_attendance')
        .select(_selectCols)
        .eq('session_id', sessionId);
    return (data as List)
        .map((e) =>
            AfterschoolAttendance.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// A child's attendance across a set of session ids (e.g. all
  /// sessions in one month).
  Future<List<AfterschoolAttendance>> fetchForChildInSessions({
    required String childId,
    required List<String> sessionIds,
  }) async {
    if (sessionIds.isEmpty) return const [];
    final data = await _client
        .from('afterschool_attendance')
        .select(_selectCols)
        .eq('child_id', childId)
        .inFilter('session_id', sessionIds);
    return (data as List)
        .map((e) =>
            AfterschoolAttendance.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Records or updates one `(session, child)` attendance. Uses the
  /// same UPSERT contract that the workshop attendance layer uses so
  /// double-tap is naturally deduped by the unique index.
  Future<void> upsertAttendance({
    required bool isStaff,
    required String sessionId,
    required String childId,
    required AttendanceStatus status,
    String? observation,
    required String markedBy,
  }) async {
    if (!isStaff) {
      throw StateError('Only staff may mark Afterschool attendance');
    }
    await _client.from('afterschool_attendance').upsert(
      {
        'session_id': sessionId,
        'child_id': childId,
        'status': status.toDb(),
        'observation':
            observation == null || observation.trim().isEmpty
                ? null
                : observation.trim(),
        'marked_by': markedBy,
        'marked_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'session_id,child_id',
    );
  }

  /// Bulk "mark all present" — one UPSERT per row so existing
  /// observations are not overwritten. Same defensive guard as the
  /// workshop equivalent.
  Future<void> markAllPresent({
    required bool isStaff,
    required String sessionId,
    required List<String> childIds,
    required String markedBy,
  }) async {
    if (!isStaff) {
      throw StateError('Only staff may mark Afterschool attendance');
    }
    if (childIds.isEmpty) return;

    final existing = await _client
        .from('afterschool_attendance')
        .select('child_id, observation')
        .eq('session_id', sessionId)
        .inFilter('child_id', childIds);
    final obs = <String, String?>{
      for (final r in (existing as List))
        (r as Map<String, dynamic>)['child_id'] as String:
            r['observation'] as String?,
    };

    final now = DateTime.now().toUtc().toIso8601String();
    final rows = childIds
        .map((cid) => {
              'session_id': sessionId,
              'child_id': cid,
              'status': 'present',
              'observation': obs[cid],
              'marked_by': markedBy,
              'marked_at': now,
            })
        .toList();
    await _client
        .from('afterschool_attendance')
        .upsert(rows, onConflict: 'session_id,child_id');
  }

  /// Deletes one attendance row. Admin-only (RLS enforces server-side).
  /// Useful when a mark was created against the wrong child; for a
  /// real absence, callers should upsert `status = absent` instead.
  Future<void> deleteAttendance({
    required bool isAdmin,
    required String attendanceId,
  }) async {
    if (!isAdmin) {
      throw StateError('Only admins may delete Afterschool attendance');
    }
    await _client
        .from('afterschool_attendance')
        .delete()
        .eq('id', attendanceId);
  }
}
