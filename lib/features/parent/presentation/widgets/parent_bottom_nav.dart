import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/parent_realtime_provider.dart';

/// Shared bottom navigation for the three top-level parent pages.
/// Sub-pages (child details, notifications) deliberately omit it and
/// use the AppBar back arrow instead.
///
/// Also acts as the lifecycle anchor for [parentNotificationsRealtimeProvider]:
/// the realtime channel stays subscribed for as long as any top-level
/// parent page is mounted (the bottom nav exists on all of them).
class ParentBottomNav extends ConsumerWidget {
  const ParentBottomNav({super.key, required this.currentIndex});

  /// 0 = Acasă (/parent), 1 = Profil (/parent/profile), 2 = Despre (/parent/about).
  final int currentIndex;

  static const _items = <_NavItem>[
    _NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Acasă',
      path: '/parent',
    ),
    _NavItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profil',
      path: '/parent/profile',
    ),
    _NavItem(
      icon: Icons.info_outline_rounded,
      activeIcon: Icons.info_rounded,
      label: 'Despre',
      path: '/parent/about',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep the parent-side realtime subscription alive while any
    // top-level parent page is mounted. AutoDispose tears the channel
    // down when the parent navigates to a sub-page or signs out.
    ref.watch(parentNotificationsRealtimeProvider);

    return SafeArea(
      top: false,
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
                selectedIcon: Icon(item.activeIcon),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.path,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;
}
