import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../data/child_progress_repository.dart';
import '../domain/child_progress.dart';

/// Riverpod wiring for the Phase 1 child_progress data layer.
///
/// Nothing on the Parent Portal / Trainer side consumes these yet —
/// Phase 1 is infrastructure only. The providers exist so Phase 2
/// pages can be wired up with a single `ref.watch` without touching
/// this file again.
///
/// Both read providers are `autoDispose.family` so a Phase 2 details
/// page can be navigated to and away from cheaply: the Supabase query
/// re-runs on fresh mount, but when the admin / trainer / parent
/// stays on the page it is cached by Riverpod for the frame tree.
/// If the Parent Portal later wants to keep history warm across
/// bottom-nav bounces, we add a non-autoDispose wrapper then — same
/// pattern as the Parent Dashboard providers.

// ── Repository provider ──────────────────────────────────────────────────────

final childProgressRepositoryProvider = Provider<ChildProgressRepository>((
  ref,
) {
  return ChildProgressRepository(ref.watch(supabaseClientProvider));
});

// ── Per-child feedback history ───────────────────────────────────────────────

/// All feedback rows for a single child, newest first. Scoped by RLS:
/// a parent sees only their own children's rows; staff sees everyone.
final childProgressByChildProvider = FutureProvider.autoDispose
    .family<List<ChildProgress>, String>((ref, childId) async {
      final repo = ref.watch(childProgressRepositoryProvider);
      return repo.fetchForChild(childId);
    });

// ── Session feedback bulk (WorkshopDetailsPage consumer) ─────────────────────

/// Every feedback row attached to a given scheduled workshop, keyed
/// by `child_id`. Single Supabase round-trip; renders N child
/// indicators without N queries.
final childProgressBySessionProvider = FutureProvider.autoDispose
    .family<Map<String, ChildProgress>, String>((
      ref,
      scheduledWorkshopId,
    ) async {
      final repo = ref.watch(childProgressRepositoryProvider);
      return repo.fetchForSession(scheduledWorkshopId);
    });

// ── Bulk feedback for a set of children (parent-portal consumer) ─────────────

/// Parameters for the Parent Portal bulk fetch. Kept as a dedicated
/// value class so `family` works with equality — Riverpod requires
/// the family argument to be `==` stable, and raw lists are not.
class ChildProgressBulkKey {
  const ChildProgressBulkKey({
    required this.childIds,
    this.sinceInclusive,
    this.limitPerChild,
  });

  final List<String> childIds;
  final DateTime? sinceInclusive;
  final int? limitPerChild;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ChildProgressBulkKey) return false;
    if (sinceInclusive != other.sinceInclusive) return false;
    if (limitPerChild != other.limitPerChild) return false;
    if (childIds.length != other.childIds.length) return false;
    for (var i = 0; i < childIds.length; i++) {
      if (childIds[i] != other.childIds[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(childIds), sinceInclusive, limitPerChild);
}

/// Single-query fetch of feedback rows across every linked child.
/// Returns a map keyed by `child_id`. The Parent Portal reads
/// `base.childIds` from `parentLinkedChildrenBaseProvider` and feeds
/// it here — one Supabase round-trip for the whole dashboard
/// extension.
final childProgressBulkProvider = FutureProvider.autoDispose
    .family<Map<String, List<ChildProgress>>, ChildProgressBulkKey>((
      ref,
      key,
    ) async {
      final repo = ref.watch(childProgressRepositoryProvider);
      return repo.fetchForChildren(
        key.childIds,
        sinceInclusive: key.sinceInclusive,
        limitPerChild: key.limitPerChild,
      );
    });
