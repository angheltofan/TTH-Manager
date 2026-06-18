import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/desktop_top_bar.dart';
import '../../providers/parent_realtime_provider.dart';
import 'parent_bottom_nav.dart';
import 'parent_sidebar.dart';

/// Width threshold above which the sidebar is shown instead of bottom nav.
/// Matches the staff `AppShell` threshold so both shells switch at the
/// same viewport size.
const _kSidebarBreakpoint = 1200.0;

/// Persistent parent-portal scaffold. Mounted **once** by the `ShellRoute`
/// in `router.dart` and wraps every `/parent/*` route. The `child` slot
/// is the only thing that swaps when the parent navigates between
/// Dashboard / Informații centru / Setări — sidebar, top bar, bottom nav
/// and the `parentNotificationsRealtimeProvider` channel stay alive.
///
/// Bottom-nav selection is derived from the current route, so individual
/// pages never have to pass an index. The mapping mirrors `ParentSidebar`
/// and `ParentBottomNav`:
///   /parent         → 0 (Dashboard)
///   /parent/info    → 1 (Informații centru)
///   /parent/settings→ 2 (Setări)
///   anything else   → unselected (e.g. /parent/notifications)
class ParentResponsiveScaffold extends ConsumerWidget {
  const ParentResponsiveScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Parent-side Supabase Realtime sync for the `notifications` table.
    // Watched here so the channel stays open across navigation — the
    // shell is mounted once for the lifetime of the parent session.
    ref.watch(parentNotificationsRealtimeProvider);

    final theme = Theme.of(context);
    final location = GoRouterState.of(context).uri.path;
    final bottomNavIndex = _indexForPath(location);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= _kSidebarBreakpoint;

        if (isDesktop) {
          return Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: Row(
              children: [
                const ParentSidebar(),
                Expanded(
                  child: Column(
                    children: [
                      const AppDesktopTopBar(
                        viewAllNotificationRoute: '/parent/notifications',
                      ),
                      Expanded(child: ClipRect(child: child)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // Mobile / tablet.
        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: const AppTopBar(
            viewAllNotificationRoute: '/parent/notifications',
          ),
          body: child,
          bottomNavigationBar:
              ParentBottomNav(currentIndex: bottomNavIndex),
        );
      },
    );
  }

  static int _indexForPath(String location) {
    if (location == '/parent') return 0;
    if (location == '/parent/info' || location.startsWith('/parent/info/')) {
      return 1;
    }
    if (location == '/parent/settings' ||
        location.startsWith('/parent/settings/')) {
      return 2;
    }
    return -1;
  }
}
