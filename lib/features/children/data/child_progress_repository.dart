import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/child_progress.dart';

/// Data layer for `public.child_progress`.
///
/// Reads are RLS-scoped by the production policy
/// `child_progress_select_staff_or_parent`:
///   • staff (admin + trainers) see every row;
///   • parents see rows only for children they are linked to via
///     `child_parents` (same `is_parent_for_child` gate used across
///     the schema).
///
/// Writes use the production policies
/// `admin_or_trainer_insert_child_progress` and
/// `admin_or_trainer_update_child_progress`:
///   • admin, and the assigned trainer of the session, can
///     INSERT/UPDATE;
///   • everyone else is refused by Postgres regardless of what the
///     Dart layer thinks.
///
/// The repository takes an `isStaff` guard on the UPSERT path so a
/// bug on the caller side fails fast with a clear message instead of
/// a bare RLS "new row violates row-level security policy" error.
class ChildProgressRepository {
  const ChildProgressRepository(this._client);

  final SupabaseClient _client;

  /// Column list fetched for every read. Session + trainer are left-
  /// joined as embedded objects; the parent client only sees the
  /// session title (parent has no SELECT on `profiles`, so the
  /// trainer object comes back null — treated as "trainer hidden").
  static const _selectCols = '''
id, child_id, scheduled_workshop_id, trainer_id, title, note, status,
built, learned, parent_message, created_at, updated_at,
scheduled_workshops!scheduled_workshop_id(
  title, workshop_date, start_time, end_time
),
trainer:profiles!trainer_id(full_name)
''';

  /// All feedback rows for a single child, newest first.
  ///
  /// RLS applies: an unauthenticated-as-this-child caller gets an
  /// empty list, not an error. The admin / trainer surfaces call this
  /// too — they just see the same shape with the trainer object
  /// populated.
  Future<List<ChildProgress>> fetchForChild(String childId) async {
    final data = await _client
        .from('child_progress')
        .select(_selectCols)
        .eq('child_id', childId)
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => ChildProgress.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Bulk fetch for the WorkshopDetailsPage — ONE query returns every
  /// feedback row attached to a session, keyed by child_id.
  ///
  /// The workshop page can carry 1..~15 enrolled children; this avoids
  /// an N+1 shape where the per-row indicator would issue one query
  /// per child. The map's absence of a key means "no feedback yet";
  /// present-but-null is impossible because the index is unique.
  Future<Map<String, ChildProgress>> fetchForSession(
    String scheduledWorkshopId,
  ) async {
    final rows = await _client
        .from('child_progress')
        .select(_selectCols)
        .eq('scheduled_workshop_id', scheduledWorkshopId);
    final out = <String, ChildProgress>{};
    for (final raw in rows as List) {
      final progress = ChildProgress.fromMap(raw as Map<String, dynamic>);
      out[progress.childId] = progress;
    }
    return out;
  }

  /// Bulk fetch for the Parent Portal — ONE query across every
  /// child the parent is linked to.
  ///
  /// Avoids the N+1 shape where the Parent Portal would issue one
  /// `fetchForChild` per linked child. Returns rows grouped by
  /// `child_id` so the UI can pick off per-child histories without
  /// re-scanning.
  Future<Map<String, List<ChildProgress>>> fetchForChildren(
    List<String> childIds, {
    DateTime? sinceInclusive,
    int? limitPerChild,
  }) async {
    if (childIds.isEmpty) return const <String, List<ChildProgress>>{};

    final query = _client
        .from('child_progress')
        .select(_selectCols)
        .inFilter('child_id', childIds);
    final rows =
        await (sinceInclusive != null
                ? query.gte(
                    'created_at',
                    sinceInclusive.toUtc().toIso8601String(),
                  )
                : query)
            .order('created_at', ascending: false);

    final grouped = <String, List<ChildProgress>>{};
    for (final raw in rows as List) {
      final progress = ChildProgress.fromMap(raw as Map<String, dynamic>);
      final list = grouped.putIfAbsent(progress.childId, () => []);
      if (limitPerChild == null || list.length < limitPerChild) {
        list.add(progress);
      }
    }
    return grouped;
  }

  /// Create or update one feedback row keyed on
  /// (child_id, scheduled_workshop_id). Backed by the Phase 1 UNIQUE
  /// constraint `uq_child_progress_child_session`.
  ///
  /// The caller must pass `isStaff: true`; the real gate is Postgres
  /// RLS (`admin_or_trainer_insert_child_progress` /
  /// `admin_or_trainer_update_child_progress`). Keeping the Dart-side
  /// guard separate from the RLS gate makes misuse obvious at the
  /// stack trace level.
  ///
  /// Fields are PATCH-shaped: pass only what you want to write. The
  /// legacy `note` column is intentionally untouched by this call —
  /// Phase 2 writes to [built] / [learned] / [parentMessage].
  Future<ChildProgress> upsertSessionFeedback({
    required bool isStaff,
    required String childId,
    required String scheduledWorkshopId,
    required String trainerId,
    String? built,
    String? learned,
    String? parentMessage,
    String? title,
    String status = 'in_progress',
  }) async {
    if (!isStaff) {
      throw StateError(
        'Only staff (admin or assigned trainer) may upsert '
        'child_progress feedback.',
      );
    }

    String? norm(String? v) {
      if (v == null) return null;
      final t = v.trim();
      return t.isEmpty ? null : t;
    }

    final payload = <String, dynamic>{
      'child_id': childId,
      'scheduled_workshop_id': scheduledWorkshopId,
      'trainer_id': trainerId,
      'title': norm(title),
      'built': norm(built),
      'learned': norm(learned),
      'parent_message': norm(parentMessage),
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    final data = await _client
        .from('child_progress')
        .upsert(payload, onConflict: 'child_id,scheduled_workshop_id')
        .select(_selectCols)
        .single();

    return ChildProgress.fromMap(data);
  }
}
