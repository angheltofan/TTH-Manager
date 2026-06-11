import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../domain/parent_base.dart';
import 'parent_dashboard_providers.dart' show parentDashboardRepositoryProvider;

/// Single source of truth for the parent's linked children.
///
/// Runs ONE `child_parents + children` query against Supabase and
/// returns a [ParentBase] consumed by every downstream parent
/// provider. Declared as a non-autoDispose `FutureProvider` so the
/// cache survives `Settings → Dashboard → Settings → Dashboard`
/// navigation — first paint after the initial sign-in is the only
/// time the query fires unless the parent's linked children actually
/// change (in which case realtime invalidation re-runs the provider).
///
/// Recomputes automatically when [currentUserProvider] changes (sign
/// in / sign out): returns [ParentBase.empty] when the auth user is
/// null, otherwise fetches the new parent's linked children.
final parentLinkedChildrenBaseProvider =
    FutureProvider<ParentBase>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return ParentBase.empty;
  return ref
      .watch(parentDashboardRepositoryProvider)
      .getLinkedChildrenBase(user.id);
});

/// Single source of truth for the parent's active workshop enrollments.
///
/// Depends on [parentLinkedChildrenBaseProvider] (so it follows the
/// same sign-in / sign-out lifecycle) and runs ONE
/// `workshop_enrollments` query for the entire linked-child set.
/// Returns a [ParentEnrollmentsBase] with the child→series and
/// series→child rollups every other provider needs. Non-autoDispose
/// for the same caching reason as the base.
final parentEnrollmentsProvider =
    FutureProvider<ParentEnrollmentsBase>((ref) async {
  final base = await ref.watch(parentLinkedChildrenBaseProvider.future);
  if (base.isEmpty) return ParentEnrollmentsBase.empty;
  return ref
      .watch(parentDashboardRepositoryProvider)
      .getEnrollmentsForBase(base);
});
