import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shared bottom navigation for the three top-level parent pages.
/// Order, labels and icons mirror [ParentSidebar] so both shells share
/// one visual language.
///
/// `currentIndex` mapping (must match the constants below and every
/// `ParentResponsiveScaffold.bottomNavIndex` call site):
///   0 = Dashboard          → /parent
///   1 = Informații centru  → /parent/about
///   2 = Setări             → /parent/profile
///
/// The parent-side realtime channel is owned by [ParentResponsiveScaffold]
/// so it stays alive on desktop too.
class ParentBottomNav extends StatelessWidget {
  const ParentBottomNav({super.key, required this.currentIndex});

  final int currentIndex;

  static const _items = <_NavItem>[
    _NavItem(
      icon: Icons.space_dashboard_outlined,
      label: 'Dashboard',
      path: '/parent',
    ),
    _NavItem(
      icon: Icons.info_outlined,
      label: 'Informații centru',
      path: '/parent/about',
    ),
    _NavItem(
      icon: Icons.tune_outlined,
      label: 'Setări',
      path: '/parent/profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Match the staff `AppShell` mobile NavigationBar metrics exactly
    // ([core/widgets/app_shell.dart] – `height: 64` + `fontSize: 12`).
    // Without this override the parent shell would inherit the Material 3
    // default 80-px height and labelMedium weight, making it visually
    // taller and heavier than the staff bottom nav.
    return SafeArea(
      top: false,
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
          selectedIndex: currentIndex,
          labelBehavior:
              NavigationDestinationLabelBehavior.onlyShowSelected,
          onDestinationSelected: (i) {
            if (i == currentIndex) return;
            context.go(_items[i].path);
          },
          destinations: _items
              .map(
                (item) => NavigationDestination(
                  icon: Icon(item.icon),
                  label: item.label,
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.path,
  });

  final IconData icon;
  final String label;
  final String path;
}
