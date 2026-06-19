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
/// Active-item detection follows the same recipe as the staff
/// [AppShell]: a single `indexWhere(...)` over the canonical nav-items
/// list, matching either an exact path or a child route via
/// `startsWith('${path}/')` — so a deep link like
/// `/parent/info/anything` still highlights "Informații centru" without
/// requiring per-path special cases.
class ParentResponsiveScaffold extends ConsumerWidget {
  const ParentResponsiveScaffold({super.key, required this.child});

  final Widget child;

  /// Canonical nav-item list used by both the bottom-nav selection logic
  /// and the desktop sidebar's active-item indicator. Order MUST match
  /// [ParentSidebar] and [ParentBottomNav] so the two surfaces stay in
  /// sync (the bottom nav reads selection by index off this list).
  static const _navItems = <_NavItem>[
    _NavItem(path: '/parent'),
    _NavItem(path: '/parent/info'),
    _NavItem(path: '/parent/settings'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Parent-side Supabase Realtime sync for the `notifications` table.
    // Watched here so the channel stays open across navigation — the
    // shell is mounted once for the lifetime of the parent session.
    ref.watch(parentNotificationsRealtimeProvider);

    final theme = Theme.of(context);
    final location = GoRouterState.of(context).uri.path;
    // Longest-match wins.
    //
    // `indexWhere` returns the FIRST hit, but `/parent` is the first
    // item and a prefix of every other parent route — so every URL
    // matched index 0 (Dashboard) before this rewrite. Scoring every
    // candidate by path length and keeping the longest match means:
    //   • `/parent`           → only `/parent` (exact)       → Dashboard
    //   • `/parent/info`      → both, `/parent/info` wins    → Info
    //   • `/parent/settings`  → both, `/parent/settings` wins → Setări
    //   • `/parent/notifications` → only `/parent` prefix → Dashboard
    //     (intentional — notifications has its own surface and is
    //     intentionally NOT a primary bottom-nav destination).
    int bottomNavIndex = -1;
    int bestMatchLen = -1;
    for (int i = 0; i < _navItems.length; i++) {
      final p = _navItems[i].path;
      final matches = location == p || location.startsWith('$p/');
      if (matches && p.length > bestMatchLen) {
        bottomNavIndex = i;
        bestMatchLen = p.length;
      }
    }

    // The persistent shell paints `child` directly into its `body:`
    // slot, which means the framework would normally try to reuse the
    // `Element` of the previous route's subtree when the new route
    // mounts (same parent, same `body:` position). Even with
    // `NoTransitionPage`, that reuse can briefly leave fragments of
    // the previous page visible. Wrapping `child` in a
    // `KeyedSubtree` keyed by the current route path forces a clean
    // element swap whenever the location changes, so the previous
    // subtree is fully disposed before the new one paints.
    final keyedBody = KeyedSubtree(key: ValueKey(location), child: child);

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
                      Expanded(child: ClipRect(child: keyedBody)),
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
          body: keyedBody,
          bottomNavigationBar:
              ParentBottomNav(currentIndex: bottomNavIndex),
        );
      },
    );
  }
}

class _NavItem {
  const _NavItem({required this.path});
  final String path;
}
