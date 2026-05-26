import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/parent_dashboard_repository.dart';
import '../domain/parent_dashboard.dart';

final parentDashboardRepositoryProvider =
    Provider<ParentDashboardRepository>((ref) {
  return ParentDashboardRepository(ref.watch(supabaseClientProvider));
});

/// All children linked to the current parent (via `child_parents`), enriched
/// with per-child summary fields.
final parentLinkedChildrenProvider =
    FutureProvider.autoDispose<List<ParentDashboardChild>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref
      .watch(parentDashboardRepositoryProvider)
      .getLinkedChildren(parentId: user.id);
});

/// Next scheduled workshop for a given child, or null if none upcoming.
final parentNextWorkshopProvider = FutureProvider.family
    .autoDispose<ParentNextWorkshop?, String>((ref, childId) {
  return ref
      .watch(parentDashboardRepositoryProvider)
      .getNextWorkshop(childId);
});

/// Last attendance / payment cycle / notification for a given child.
final parentRecentActivityProvider = FutureProvider.family
    .autoDispose<ParentRecentActivity, String>((ref, childId) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const ParentRecentActivity();
  return ref.watch(parentDashboardRepositoryProvider).getRecentActivity(
        childId: childId,
        parentId: user.id,
      );
});

/// Active workshops for a child, used by the read-only Parent Child Details
/// page.
final parentActiveWorkshopsProvider = FutureProvider.family
    .autoDispose<List<ParentNextWorkshop>, String>((ref, childId) {
  return ref
      .watch(parentDashboardRepositoryProvider)
      .getActiveWorkshops(childId);
});

/// Basic child info (name, birth date, is_active) for the read-only
/// Parent Child Details page.
final parentChildBasicProvider = FutureProvider.family
    .autoDispose<Map<String, dynamic>?, String>((ref, childId) {
  return ref
      .watch(parentDashboardRepositoryProvider)
      .getChildBasic(childId);
});

/// Payment cycle history for a child (read-only).
final parentChildPaymentCyclesProvider = FutureProvider.family
    .autoDispose<List<Map<String, dynamic>>, String>((ref, childId) {
  return ref
      .watch(parentDashboardRepositoryProvider)
      .getPaymentCycles(childId);
});
