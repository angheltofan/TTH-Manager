import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    _NavItem(icon: Icons.badge_outlined, label: 'Traineri', path: '/trainers'),
    _NavItem(icon: Icons.tune_outlined, label: 'Setări', path: '/settings'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        return Scaffold(
          appBar: const AppTopBar(),
          body: child,
          bottomNavigationBar: SafeArea(
            bottom: true,
            child: Theme(
              data: Theme.of(context).copyWith(
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

