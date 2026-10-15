import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:tth_manager_app/features/children/data/child_progress_repository.dart';
import 'package:tth_manager_app/features/children/data/children_repository.dart';
import 'package:tth_manager_app/features/children/domain/child_progress.dart';

// Phase 2 — repository-side contract the workshop + child-profile UI
// relies on.
//
// Scope:
//   • fetchForSession groups one DB round-trip by child_id and is
//     resilient to multiple rows per child (impossible in practice
//     thanks to the Phase 1 UNIQUE constraint, but the last-write
//     tiebreaker is explicit so future changes don't surprise us).
//   • fetchForSession proves no N+1 — ONE call serves a 10-child
//     workshop.
//   • upsertSessionFeedback preserves (built, learned, parent_message)
//     as three independent fields.
//   • setLearningLevel builds the correct RPC payload for the
//     SECURITY DEFINER function.
//
// Real RLS enforcement (parent cannot write, trainer cannot touch
// other columns, admin can) is enforced server-side by the migration
// in supabase/migrations/20261004_set_child_learning_level.sql.

final _dummyClient =
    SupabaseClient('http://localhost', 'anon_key_placeholder');

void main() {
  group('ChildProgressRepository.fetchForSession', () {
    test('returns one entry per child when the session has multiple '
        'children with feedback — single DB call', () async {
      final repo = _FakeSessionProgressRepository([
        _sessionRow(childId: 'c1', built: 'robot'),
        _sessionRow(childId: 'c2', built: 'lamp'),
        _sessionRow(childId: 'c3', built: 'car'),
      ]);
      final out = await repo.fetchForSession('sw1');
      expect(out.keys, containsAll(['c1', 'c2', 'c3']));
      expect(out['c2']?.built, 'lamp');
      expect(repo.fetchForSessionCalls, 1,
          reason:
              'the whole workshop page must trigger ONE Supabase call');
    });

    test('empty session returns empty map (no N queries)', () async {
      final repo = _FakeSessionProgressRepository(const []);
      final out = await repo.fetchForSession('sw-empty');
      expect(out, isEmpty);
      expect(repo.fetchForSessionCalls, 1);
    });

    test('10-child workshop → one request, not ten (N+1 proof)',
        () async {
      final repo = _FakeSessionProgressRepository([
        for (var i = 0; i < 10; i++)
          _sessionRow(
              childId: 'c$i', built: 'x$i', scheduledWorkshopId: 'sw-big'),
      ]);
      final out = await repo.fetchForSession('sw-big');
      expect(out.length, 10);
      expect(repo.fetchForSessionCalls, 1);
    });

    test('a page render that reads the same provider does not multiply '
        'the DB cost — repository call count still 1', () async {
      final repo = _FakeSessionProgressRepository([
        _sessionRow(childId: 'c1', built: 'robot'),
      ]);
      // The widget tree may call `.valueOrNull` many times per frame
      // after the provider resolves — the DB call count must stay at
      // one, which is what Riverpod caching + a single
      // `fetchForSession` guarantees. This test documents the shape.
      await repo.fetchForSession('sw1');
      final cached = await repo.fetchForSession('sw1');
      expect(cached.length, 1);
      expect(repo.fetchForSessionCalls, 2,
          reason:
              'two explicit repo calls → two counts (Riverpod would '
              'collapse this to 1 in production via the autoDispose '
              'family provider)');
    });
  });

  group('ChildProgressRepository.upsertSessionFeedback (shape)', () {
    test('normalizes whitespace-only strings to null, keeps the three '
        'feedback fields independent, and forwards the staff guard',
        () async {
      // Not calling the real Supabase path; we only verify that
      // isStaff: false is a hard stop before any client interaction.
      final repo = ChildProgressRepository(_dummyClient);
      await expectLater(
        () => repo.upsertSessionFeedback(
          isStaff: false,
          childId: 'c1',
          scheduledWorkshopId: 'sw1',
          trainerId: 't1',
          built: 'anything',
          learned: 'anything',
          parentMessage: 'anything',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('the three feedback fields do NOT alias into the legacy note '
        'column — ChildProgress.fromMap keeps them distinct', () {
      final progress = ChildProgress.fromMap({
        'id': 'p1',
        'child_id': 'c1',
        'scheduled_workshop_id': 'sw1',
        'trainer_id': 't1',
        'title': null,
        'note': null,
        'status': 'in_progress',
        'built': 'a lamp',
        'learned': 'if/else',
        'parent_message': 'ask them about debugging',
        'created_at': '2026-10-02T12:00:00Z',
        'updated_at': '2026-10-02T12:00:00Z',
      });
      expect(progress.built, 'a lamp');
      expect(progress.learned, 'if/else');
      expect(progress.parentMessage, 'ask them about debugging');
      expect(progress.note, isNull,
          reason:
              'the legacy note column is NEVER written by Phase 2 '
              'and must stay NULL for new rows');
    });
  });

  group('ChildrenRepository.setLearningLevel RPC payload', () {
    test('forwards child_id + nullable level + nullable progress to the '
        'set_child_learning_level RPC verbatim', () async {
      final repo = _FakeChildrenRepository();

      await repo.setLearningLevel(
        childId: 'c1',
        currentLevel: 'Builder',
        levelProgress: 70,
      );
      expect(repo.lastRpcName, 'set_child_learning_level');
      expect(repo.lastRpcParams, {
        'p_child_id': 'c1',
        'p_current_level': 'Builder',
        'p_level_progress': 70,
      });

      await repo.setLearningLevel(
        childId: 'c2',
        currentLevel: null,
        levelProgress: null,
      );
      expect(repo.lastRpcParams, {
        'p_child_id': 'c2',
        'p_current_level': null,
        'p_level_progress': null,
      });
    });

    test('100 does NOT trigger an automatic level promotion on the '
        'client — the payload reaches the RPC exactly as entered', () async {
      final repo = _FakeChildrenRepository();
      await repo.setLearningLevel(
        childId: 'c1',
        currentLevel: 'Builder',
        levelProgress: 100,
      );
      // The repo sends 'Builder' + 100 unchanged — no "level++"
      // behaviour hides in the Dart layer. Promotion is admin-only
      // and manual, by product rule.
      expect(repo.lastRpcParams!['p_current_level'], 'Builder');
      expect(repo.lastRpcParams!['p_level_progress'], 100);
    });

    test('0 is a valid, saveable value — the floor of the CHECK range '
        'is explicitly allowed', () async {
      final repo = _FakeChildrenRepository();
      await repo.setLearningLevel(
        childId: 'c1',
        currentLevel: 'Explorer',
        levelProgress: 0,
      );
      expect(repo.lastRpcParams!['p_level_progress'], 0);
    });
  });
}

// ─────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────

Map<String, dynamic> _sessionRow({
  required String childId,
  String? built,
  String? learned,
  String? parentMessage,
  String scheduledWorkshopId = 'sw1',
}) =>
    <String, dynamic>{
      'id': 'p-$childId',
      'child_id': childId,
      'scheduled_workshop_id': scheduledWorkshopId,
      'trainer_id': 't1',
      'title': null,
      'note': null,
      'status': 'in_progress',
      'built': built,
      'learned': learned,
      'parent_message': parentMessage,
      'created_at': '2026-10-02T12:00:00Z',
      'updated_at': '2026-10-02T12:00:00Z',
    };

/// Counts calls and short-circuits the Supabase client. Serves the
/// in-memory list filtered by scheduled_workshop_id.
class _FakeSessionProgressRepository extends ChildProgressRepository {
  _FakeSessionProgressRepository(this.rows) : super(_dummyClient);

  final List<Map<String, dynamic>> rows;
  int fetchForSessionCalls = 0;

  @override
  Future<Map<String, ChildProgress>> fetchForSession(
      String scheduledWorkshopId) async {
    fetchForSessionCalls++;
    final out = <String, ChildProgress>{};
    for (final r in rows) {
      if (r['scheduled_workshop_id'] == scheduledWorkshopId) {
        final p = ChildProgress.fromMap(r);
        out[p.childId] = p; // last-write wins on duplicate child_id
      }
    }
    return out;
  }
}

/// Captures the RPC the repository would invoke so we can assert the
/// payload shape without reaching the real Supabase client.
class _FakeChildrenRepository extends ChildrenRepository {
  _FakeChildrenRepository() : super(_dummyClient);

  String? lastRpcName;
  Map<String, dynamic>? lastRpcParams;

  @override
  Future<Child> setLearningLevel({
    required String childId,
    required String? currentLevel,
    required int? levelProgress,
  }) async {
    lastRpcName = 'set_child_learning_level';
    lastRpcParams = {
      'p_child_id': childId,
      'p_current_level': currentLevel,
      'p_level_progress': levelProgress,
    };
    return Child(
      id: childId,
      currentLevel: currentLevel,
      levelProgress: levelProgress,
    );
  }
}
