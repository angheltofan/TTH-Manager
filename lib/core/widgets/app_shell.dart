import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/team_chat/providers/team_chat_providers.dart';
import '../providers/app_realtime_provider.dart';
import '../theme/app_theme.dart';
import 'sidebar.dart';
import 'sidebar_base.dart';
import 'staff_nav_items.dart';
import 'top_bar.dart';

/// Width threshold above which the sidebar is shown instead of the
/// mobile navigation drawer + top-bar hamburger.
const _kSidebarBreakpoint = 1200.0;

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Centralized Supabase Realtime sync — one provider for all
    // subscribed tables. Active only for authenticated admin/trainer
    // users. AutoDispose removes channels on logout.
    ref.watch(appRealtimeProvider);
    // Team chat has its own dedicated realtime channel.
    ref.watch(teamChatRealtimeProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Desktop / large-tablet: static left rail, no drawer.
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

        // Mobile / tablet: hamburger opens a Drawer; no bottom nav.
        // The AppBar inside [AppTopBar] auto-injects the drawer icon
        // as its leading because Scaffold.drawer is set on this
        // Scaffold ancestor and its `automaticallyImplyLeading` stays
        // at its default (true).
        return Scaffold(
          appBar: const AppTopBar(),
          drawer: const _StaffNavDrawer(),
          body: child,
        );
      },
    );
  }
}

/// Navigation drawer for staff users on mobile / tablet. Reuses the
/// same destinations as [AppSidebar] via [kStaffAllNav] — one source
/// of truth. Highlights the active destination using the same
/// prefix-match rule the sidebar uses (`location.startsWith('$path/')`
/// with an exact-match exception for `/dashboard` and the parent root).
class _StaffNavDrawer extends StatelessWidget {
  const _StaffNavDrawer();

  bool _isActive(String currentPath, String itemPath) {
    // Exact match for the dashboard root: any /parent path or another
    // top-level would otherwise accidentally match "" prefix rules.
    if (itemPath == '/dashboard') return currentPath == '/dashboard';
    if (currentPath == itemPath) return true;
    return currentPath.startsWith('$itemPath/');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = GoRouterState.of(context).uri.path;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.purple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_awesome,
                        color: AppColors.purple, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TTH Manager',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Tales & Tech HUB',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(
                height: 1,
                color: theme.colorScheme.outline.withValues(alpha: 0.15)),
            const SizedBox(height: 6),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  for (final item in kStaffAllNav)
                    _DrawerItem(
                      item: item,
                      active: _isActive(location, item.path),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({required this.item, required this.active});
  final SidebarNavItem item;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = active
        ? AppColors.purple
        : theme.colorScheme.onSurface.withValues(alpha: 0.85);
    final bg = active
        ? AppColors.purple.withValues(alpha: 0.10)
        : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            // Close the drawer first so navigation doesn't overlap
            // with the drawer animation.
            Navigator.of(context).pop();
            if (!active) context.go(item.path);
          },
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(item.activeIcon ?? item.icon, size: 20, color: tint),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    item.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: tint,
                      fontWeight:
                          active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (active)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.purple,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
