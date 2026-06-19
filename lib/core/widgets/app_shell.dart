import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/team_chat/providers/team_chat_providers.dart';
import '../providers/app_realtime_provider.dart';
import 'bottom_nav_safe_area.dart';
import 'sidebar.dart';
import 'top_bar.dart';

/// Width threshold above which the sidebar is shown instead of bottom nav.
const _kSidebarBreakpoint = 1200.0;

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const _navItems = [
    _NavItem(icon: Icons.space_dashboard_outlined, label: 'Dashboard', path: '/dashboard'),
    _NavItem(icon: Icons.groups_outlined, label: 'Copii', path: '/children'),
    _NavItem(icon: Icons.auto_awesome_outlined, label: 'Asistent', path: '/assistant'),
    _NavItem(icon: Icons.tune_outlined, label: 'Setări', path: '/settings'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep the global Team Chat realtime listener alive while the shell is
    // mounted (i.e. while any authenticated user is using the app).
    // The provider itself gates on admin/trainer roles, so non-staff users
    // won't subscribe. AutoDispose removes the channel on logout.
    // Centralized Supabase Realtime sync — one provider for all 8 tables.
    // Active only for authenticated admin/trainer users. AutoDispose removes
    // channels on logout.
    ref.watch(appRealtimeProvider);
    // Team chat has its own dedicated realtime channel (handles badge logic).
    ref.watch(teamChatRealtimeProvider);

    final location = GoRouterState.of(context).uri.path;
    final currentIndex = _navItems.indexWhere(
      (item) => location == item.path || location.startsWith('${item.path}/'),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Desktop sidebar layout — only on large screens (≥ 1200px).
        if (constraints.maxWidth >= _kSidebarBreakpoint) {
          return Scaffold(
            body: Row(
              children: [
                const AppSidebar(),
                Expanded(
                  child: Column(
                    children: [
                      const AppDesktopTopBar(),
                      Expanded(child: ClipRect(child: child)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // Mobile / tablet — bottom nav bar + top bar.
        final theme = Theme.of(context);
        // Match the colour [NavigationBar] paints by default (M3 default
        // is `colorScheme.surfaceContainer`) so [BottomNavSafeArea]'s
        // extension into the iPhone home-indicator zone is visually
        // continuous with the bar above it.
        final navBg = theme.navigationBarTheme.backgroundColor ??
            theme.colorScheme.surfaceContainer;
        return Scaffold(
          appBar: const AppTopBar(),
          body: child,
          bottomNavigationBar: BottomNavSafeArea(
            backgroundColor: navBg,
            child: Theme(
              data: theme.copyWith(
                navigationBarTheme: NavigationBarThemeData(
                  height: 64,
                  labelTextStyle: WidgetStateProperty.resolveWith((states) {
                    return const TextStyle(fontSize: 12);
                  }),
                ),
              ),
              child: NavigationBar(
                selectedIndex: currentIndex < 0 ? 0 : currentIndex,
                onDestinationSelected: (i) => context.go(_navItems[i].path),
                labelBehavior:
                    NavigationDestinationLabelBehavior.onlyShowSelected,
                destinations: _navItems
                    .map((item) => NavigationDestination(
                          icon: Icon(item.icon),
                          label: item.label,
                        ))
                    .toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.label, required this.path});
  final IconData icon;
  final String label;
  final String path;
}

