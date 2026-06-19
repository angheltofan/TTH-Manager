import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_providers.dart';
import '../../features/dashboard/providers/dashboard_providers.dart';
import '../../features/demo_workshops/providers/demo_workshops_providers.dart';
import '../../features/notifications/providers/notifications_providers.dart';
import '../../features/parent/providers/parent_dashboard_providers.dart';

/// Single source of truth for "the app is ready to show its first screen".
///
/// Waits on every piece of data that the first painted route needs so the
/// branded splash stays visible until the destination is fully populated —
/// no more `CircularProgressIndicator` flashes on the dashboard immediately
/// after splash dismissal.
///
/// Stages, gated sequentially:
///   1. [authStateProvider] emits → we know logged-in vs anonymous.
///   2. If anonymous → done (router redirects to `/login`).
///   3. [currentProfileProvider] resolves → role is known so we can pick
///      which first-screen data to preload.
///   4. Role fan-out, awaited in parallel via `Future.wait`:
///        • Staff: dashboard stats, today's workshops, today's demos,
///          unread-count badge.
///        • Parent: linked children, next-workshop KPI, attendance-rate
///          KPI, weekly schedule, recent activity feed.
///      Per-provider failures are swallowed here — the destination screen
///      already renders an inline error for any provider that throws, so
///      a single bad query does not strand the user on the splash.
///
/// Errors in the auth/profile chain are also caught and treated as "done":
/// the splash dismisses, the destination screen surfaces the real error
/// inline (e.g. profile-fetch failure). Staying on the splash forever
/// would be worse UX than rendering the route in its error state.
final startupBootstrapProvider = FutureProvider<void>((ref) async {
  try {
    await ref.watch(authStateProvider.future);
  } catch (_) {
    return;
  }

  final user = ref.read(currentUserProvider);
  if (user == null) return;

  final profile = await ref.watch(currentProfileProvider.future).catchError(
        (_) => null,
      );
  if (profile == null) return;

  final futures = <Future<void>>[];

  if (profile.isParent) {
    futures.addAll([
      _absorb(ref.watch(parentLinkedChildrenProvider.future)),
      _absorb(ref.watch(parentNextWorkshopSummaryProvider.future)),
      _absorb(ref.watch(parentAttendanceRateSummaryProvider.future)),
      _absorb(ref.watch(parentWeeklyScheduleProvider.future)),
      _absorb(ref.watch(parentRecentActivityFeedProvider(3).future)),
      _absorb(ref.watch(unreadCountFutureProvider.future)),
    ]);
  } else if (profile.isStaff) {
    futures.addAll([
      _absorb(ref.watch(dashboardStatsProvider.future)),
      _absorb(ref.watch(todayWorkshopsProvider.future)),
      _absorb(ref.watch(todayDemoWorkshopsProvider.future)),
      _absorb(ref.watch(unreadCountFutureProvider.future)),
    ]);
  }

  if (futures.isNotEmpty) await Future.wait(futures);
});

/// Awaits [future] and absorbs any thrown error so a single failing query
/// does not leave the bootstrap (and the splash) hanging indefinitely.
/// The destination widget renders its own per-provider error UI when it
/// later watches the same provider.
Future<void> _absorb(Future<Object?> future) async {
  try {
    await future;
  } catch (_) {
    // intentional — surfaced by the destination widget's own ref.watch.
  }
}
