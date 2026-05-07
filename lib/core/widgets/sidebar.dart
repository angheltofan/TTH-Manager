import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor =
        isDark ? AppColors.sidebarDarkBg : AppColors.sidebarLightBg;
    final borderColor =
        isDark ? AppColors.borderDark : AppColors.borderLight;
    final titleColor = theme.colorScheme.onSurface;
    final subtitleColor = theme.colorScheme.outline;

    return Container(
      width: 248,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          right: BorderSide(color: borderColor),
        ),
      ),
      child: Column(
        children: [
          // ── Logo area ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Image.asset(
                    'assets/images/app_logo.png',
                    width: 40,
                    height: 40,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TTH Manager',
                        style: TextStyle(
                          color: titleColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          letterSpacing: 0.1,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Tales & Tech HUB',
                        style: TextStyle(
                          color: subtitleColor,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Divider(
            color: borderColor,
            height: 1,
            indent: 20,
            endIndent: 20,
          ),
          const SizedBox(height: 12),

          // ── Nav items ──────────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _SideNavItem(
                  icon: Icons.space_dashboard_outlined,
                  label: 'Dashboard',
                  path: '/dashboard',
                  selected: location == '/dashboard',
                  isDark: isDark,
                ),
                _SideNavItem(
                  icon: Icons.groups_outlined,
                  label: 'Copii',
                  path: '/children',
                  selected: location.startsWith('/children'),
                  isDark: isDark,
                ),
                _SideNavItem(
                  icon: Icons.badge_outlined,
                  label: 'Traineri',
                  path: '/trainers',
                  selected: location.startsWith('/trainers'),
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    'CONT',
                    style: TextStyle(
                      color: subtitleColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                _SideNavItem(
                  icon: Icons.tune_outlined,
                  label: 'Setări',
                  path: '/settings',
                  selected: location.startsWith('/settings'),
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SideNavItem extends StatelessWidget {
  const _SideNavItem({
    required this.icon,
    required this.label,
    required this.path,
    required this.selected,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final String path;
  final bool selected;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Adaptive active/inactive colors.
    final activeAccent =
        isDark ? AppColors.navAccentDark : AppColors.purple;
    final activeBg =
        isDark ? AppColors.navActiveDarkBg : AppColors.navActiveLightBg;
    final inactiveColor = theme.colorScheme.outline;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => context.go(path),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: selected ? activeBg : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: selected ? activeAccent : inactiveColor,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? activeAccent : inactiveColor,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 14,
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
