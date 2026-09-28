import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/afterschool_session.dart';

/// Data layer for `afterschool_sessions`. Reads go through SELECT
/// with RLS; state changes (close/reopen, generation) go through
/// SECURITY DEFINER RPCs so the audit metadata (`closed_by`,
/// `closed_at`) is populated from server-side `auth.uid()`.
class AfterschoolSessionsRepository {
  const AfterschoolSessionsRepository(this._client);

  final SupabaseClient _client;

  static const _selectCols = '''
id, program_id, session_date, start_time, end_time, variant,
is_closed, closed_reason, closed_by, closed_at, created_at
''';

  /// Fetches the session for `date` (if any).
  Future<AfterschoolSession?> fetchByDate({
    required String programId,
    required DateTime date,
  }) async {
    final data = await _client
        .from('afterschool_sessions')
        .select(_selectCols)
        .eq('program_id', programId)
        .eq('session_date', _dateOnly(date))
        .maybeSingle();
    if (data == null) return null;
    return AfterschoolSession.fromMap(data);
  }

  /// All sessions in `[year, month]`, ordered by date ASC. Includes
  /// closed sessions — the caller decides how to render them.
  Future<List<AfterschoolSession>> fetchForMonth({
    required String programId,
    required int year,
    required int month,
  }) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0);
    final data = await _client
        .from('afterschool_sessions')
        .select(_selectCols)
        .eq('program_id', programId)
        .gte('session_date', _dateOnly(start))
        .lte('session_date', _dateOnly(end))
        .order('session_date');
    return (data as List)
        .map((e) => AfterschoolSession.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Materialises missing sessions in `[from, to]` for one program.
  /// Idempotent (unique index on program_id + session_date). Returns
  /// the number of new rows inserted.
  Future<int> generateWindow({
    required String programId,
    required DateTime from,
    required DateTime to,
  }) async {
    final res = await _client.rpc(
      'generate_afterschool_sessions_window',
      params: {
        'p_program_id': programId,
        'p_from': _dateOnly(from),
        'p_to': _dateOnly(to),
      },
    );
    if (res is int) return res;
    if (res is num) return res.toInt();
    return 0;
  }

  /// Marks a session CLOSED. Server captures the acting user id.
  Future<void> closeSession({
    required String sessionId,
    String? reason,
  }) async {
    await _client.rpc('close_afterschool_session', params: {
      'p_session_id': sessionId,
      if (reason != null && reason.trim().isNotEmpty)
        'p_reason': reason.trim(),
    });
  }

  /// Reverses `closeSession`.
  Future<void> reopenSession({required String sessionId}) async {
    await _client.rpc('reopen_afterschool_session', params: {
      'p_session_id': sessionId,
    });
  }

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
