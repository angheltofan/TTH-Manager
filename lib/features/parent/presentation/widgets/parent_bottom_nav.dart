import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/bottom_nav_safe_area.dart';

/// Shared bottom navigation for the three top-level parent pages.
/// Order, labels and icons mirror [ParentSidebar] so both shells share
/// one visual language.
///
/// `currentIndex` mapping (must match the constants below and the
/// `_indexForPath` helper in [ParentResponsiveScaffold]):
///   0  = Dashboard          → /parent
///   1  = Informații centru  → /parent/info
///   2  = Setări             → /parent/settings
///   -1 = no top-level match (e.g. /parent/notifications) — bottom nav
///        renders with nothing selected
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
      path: '/parent/info',
    ),
    _NavItem(
      icon: Icons.tune_outlined,
      label: 'Setări',
      path: '/parent/settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Match the staff `AppShell` mobile NavigationBar metrics exactly
    // ([core/widgets/app_shell.dart] – `height: 64` + `fontSize: 12`).
    // Without this override the parent shell would inherit the Material 3
    // default 80-px height and labelMedium weight, making it visually
    // taller and heavier than the staff bottom nav.
    final theme = Theme.of(context);
    // Match the colour [NavigationBar] paints by default (M3 default
    // is `colorScheme.surfaceContainer`) so [BottomNavSafeArea]'s
    // extension into the iPhone home-indicator zone is visually
    // continuous with the bar above it.
    final navBg = theme.navigationBarTheme.backgroundColor ??
        theme.colorScheme.surfaceContainer;
    return BottomNavSafeArea(
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
          // NavigationBar asserts the index is in range, so clamp
          // unselected (-1) back to 0. Matches the staff `AppShell`
          // behaviour for the same edge case.
          selectedIndex: currentIndex < 0 ? 0 : currentIndex,
          // Unconditional navigation mirrors the staff `AppShell`
          // bottom-nav handler: re-tapping the active item still calls
          // `context.go(...)`. GoRouter treats this as a no-op when the
          // location is already current, but the symmetry avoids any
          // asymmetric feedback between the two shells.
          onDestinationSelected: (i) => context.go(_items[i].path),
          labelBehavior:
              NavigationDestinationLabelBehavior.onlyShowSelected,
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
