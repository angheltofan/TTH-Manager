import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/afterschool_program.dart';

/// Data layer for `afterschool_programs`.
///
/// Every write path is admin-only via RLS (`is_admin()`). The client
/// still passes `isAdmin` as a defensive check so we surface a clean
/// `StateError` instead of an opaque RLS denial from the server.
class AfterschoolProgramsRepository {
  const AfterschoolProgramsRepository(this._client);

  final SupabaseClient _client;

  static const _selectCols = '''
id, name, description, days_of_week, start_time, end_time,
monthly_fee, currency, max_capacity, active_from, active_to, is_active,
archived_at, archived_by, archived_reason, notes, created_at, updated_at
''';

  Future<List<AfterschoolProgram>> fetchAll({
    bool activeOnly = true,
  }) async {
    final query = _client
        .from('afterschool_programs')
        .select(_selectCols);
    final data = await (activeOnly
            ? query.eq('is_active', true).filter('archived_at', 'is', null)
            : query)
        .order('name');
    return (data as List)
        .map((e) => AfterschoolProgram.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<AfterschoolProgram?> fetchById(String id) async {
    final data = await _client
        .from('afterschool_programs')
        .select(_selectCols)
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return AfterschoolProgram.fromMap(data);
  }

  /// Creates a new program. Admin-only.
  ///
  /// [daysOfWeek] MUST use ISO weekday numbers (1 = Monday .. 7 =
  /// Sunday). The DB CHECK constraint enforces the range; passing
  /// arbitrary integers will hit `chk_afs_prog_days_of_week`.
  Future<AfterschoolProgram> create({
    required bool isAdmin,
    required String name,
    String? description,
    required Set<int> daysOfWeek,
    required String startTime,
    required String endTime,
    required double monthlyFee,
    String currency = 'RON',
    int? maxCapacity,
    required DateTime activeFrom,
    DateTime? activeTo,
    String? notes,
  }) async {
    if (!isAdmin) {
      throw StateError('Only admins may create Afterschool programs');
    }
    if (maxCapacity != null && maxCapacity <= 0) {
      throw ArgumentError.value(
          maxCapacity, 'maxCapacity', 'must be > 0 when set');
    }
    final payload = {
      'name': name.trim(),
      'description': description,
      'days_of_week': daysOfWeek.toList()..sort(),
      'start_time': startTime,
      'end_time': endTime,
      'monthly_fee': monthlyFee,
      'currency': currency,
      'max_capacity': ?maxCapacity,
      'active_from': _dateOnly(activeFrom),
      if (activeTo != null) 'active_to': _dateOnly(activeTo),
      'notes': notes,
    };
    final inserted = await _client
        .from('afterschool_programs')
        .insert(payload)
        .select(_selectCols)
        .single();
    return AfterschoolProgram.fromMap(inserted);
  }

  /// Updates any subset of program fields. Admin-only. The map is
  /// filtered client-side to reject unknown keys before hitting the
  /// wire; DB CHECK constraints re-validate.
  Future<void> update({
    required bool isAdmin,
    required String id,
    required Map<String, dynamic> patch,
  }) async {
    if (!isAdmin) {
      throw StateError('Only admins may edit Afterschool programs');
    }
    const allowed = {
      'name',
      'description',
      'days_of_week',
      'start_time',
      'end_time',
      'monthly_fee',
      'currency',
      'max_capacity',
      'active_from',
      'active_to',
      'is_active',
      'notes',
    };
    final clean = <String, dynamic>{
      for (final entry in patch.entries)
        if (allowed.contains(entry.key)) entry.key: entry.value,
    };
    if (clean.isEmpty) return;
    await _client
        .from('afterschool_programs')
        .update(clean)
        .eq('id', id);
  }

  /// Retires a program: `is_active = false` + `archived_at = now()` +
  /// `archived_by` + optional `archived_reason`. Sessions and
  /// enrollments remain — Phase 3+ code will filter them out based on
  /// the archived state.
  Future<void> archive({
    required bool isAdmin,
    required String id,
    required String adminId,
    String? reason,
  }) async {
    if (!isAdmin) {
      throw StateError('Only admins may archive Afterschool programs');
    }
    final payload = <String, dynamic>{
      'is_active': false,
      'archived_at': DateTime.now().toUtc().toIso8601String(),
      'archived_by': adminId,
      if (reason != null && reason.trim().isNotEmpty)
        'archived_reason': reason.trim(),
    };
    await _client
        .from('afterschool_programs')
        .update(payload)
        .eq('id', id);
  }

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
