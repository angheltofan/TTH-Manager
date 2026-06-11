import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/desktop_top_bar.dart';
import '../../providers/parent_realtime_provider.dart';
import 'parent_bottom_nav.dart';
import 'parent_sidebar.dart';

/// Width threshold above which the sidebar is shown instead of bottom nav.
/// Matches the staff `AppShell` threshold so both shells switch at the
/// same viewport size.
const _kSidebarBreakpoint = 1200.0;

/// Shared scaffold used by all three top-level parent pages (Acasă,
/// Profil, Despre). Visual structure mirrors the staff [AppShell] 1:1
/// by reusing the same top-bar widgets:
///   - desktop (≥ 1200): [ParentSidebar] + content column whose top is
///     [AppDesktopTopBar] (title left, notification bell + user menu
///     right) and a hairline divider below.
///   - mobile/tablet: [AppTopBar] (toolbar 56 + bottom divider, full
///     `compact` user menu on small phones) + [ParentBottomNav].
///
/// `bottomNavIndex` matches [ParentBottomNav]:
///   0 = Dashboard, 1 = Informații centru, 2 = Setări.
///
/// `title` is unused at runtime — both shared top bars derive their
/// title from the current route via `titleForPath`, which knows about
/// `/parent/*` paths. The parameter is kept for API stability so all
/// existing call sites continue to compile and for documentation at
/// the page level.
class ParentResponsiveScaffold extends ConsumerWidget {
  const ParentResponsiveScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.bottomNavIndex,
    this.onRefresh,
  });

  final String title;
  final Widget body;
  final int bottomNavIndex;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Parent-side Supabase Realtime sync for the `notifications` table.
    // Watched here (instead of inside `ParentBottomNav`) so the channel
    // is also alive on desktop, where the bottom nav widget never mounts
    // and the sidebar is rendered instead. AutoDispose tears the channel
    // down on sign-out.
    ref.watch(parentNotificationsRealtimeProvider);

    final theme = Theme.of(context);

    final wrappedBody = onRefresh != null
        ? RefreshIndicator(onRefresh: onRefresh!, child: body)
        : body;

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
                      Expanded(child: ClipRect(child: wrappedBody)),
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
          body: wrappedBody,
          bottomNavigationBar: ParentBottomNav(currentIndex: bottomNavIndex),
        );
      },
    );
  }
}
