import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

/// Shared visual primitive for left-rail navigation. Both the staff
/// `AppSidebar` and the parent `ParentSidebar` render through this
/// widget so width, padding, logo treatment, divider, item style, and
/// adaptive light/dark colours stay identical across roles.
///
/// Brand block (top of the sidebar): the app logo is centered, with
/// the [logoSubtitle] (e.g. "Tales & Tech HUB") centered below it.
/// The product name "TTH Manager" lives in the top bar instead of
/// being repeated here.
///
/// An optional [sectionLabel] + [trailingItems] list lets a sidebar
/// add a "CONT" group after the primary items (e.g. Setări for staff).
/// No business logic lives here.
class AppSidebarBase extends StatelessWidget {
  const AppSidebarBase({
    super.key,
    required this.logoSubtitle,
    required this.items,
    this.sectionLabel,
    this.trailingItems = const [],
  });

  /// Brand line under the logo, e.g. "Tales & Tech HUB".
  final String logoSubtitle;

  /// Navigation rows rendered in the order supplied.
  final List<SidebarNavItem> items;

  /// Optional uppercase section label rendered above [trailingItems]
  /// (e.g. "CONT"). When null the trailing group is rendered without a
  /// header.
  final String? sectionLabel;

  /// Optional rows rendered after the primary group. Used by staff for
  /// "Setări"; parent currently passes none.
  final List<SidebarNavItem> trailingItems;

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
        border: Border(right: BorderSide(color: borderColor)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Image.asset(
                      'assets/images/app_logo.png',
                      width: 56,
                      height: 56,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    logoSubtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: titleColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      letterSpacing: 0.1,
                    ),
                    overflow: TextOverflow.ellipsis,
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
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final item in items)
                    _SideNavRow(
                      item: item,
                      selected: _isSelected(location, item.path),
                      isDark: isDark,
                    ),
                  if (trailingItems.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    if (sectionLabel != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: Text(
                          sectionLabel!,
                          style: TextStyle(
                            color: subtitleColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    for (final item in trailingItems)
                      _SideNavRow(
                        item: item,
                        selected: _isSelected(location, item.path),
                        isDark: isDark,
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Exact-match for "/" home routes; prefix-match otherwise (so
  /// `/children/123/edit` highlights "Copii").
  static bool _isSelected(String location, String path) {
    if (path == '/parent' || path == '/dashboard') {
      return location == path;
    }
    return location == path || location.startsWith('$path/');
  }
}

/// Declarative description of one nav row.
class SidebarNavItem {
  const SidebarNavItem({
    required this.icon,
    required this.label,
    required this.path,
    this.activeIcon,
  });

  /// Icon used when this item is NOT the active route.
  final IconData icon;

  /// Optional outline-filled variant used when active. Falls back to
  /// [icon] when null (matches the staff sidebar's current behaviour).
  final IconData? activeIcon;

  final String label;
  final String path;
}

class _SideNavRow extends StatelessWidget {
  const _SideNavRow({
    required this.item,
    required this.selected,
    required this.isDark,
  });

  final SidebarNavItem item;
  final bool selected;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeAccent =
        isDark ? AppColors.navAccentDark : AppColors.purple;
    final activeBg =
        isDark ? AppColors.navActiveDarkBg : AppColors.navActiveLightBg;
    final inactiveColor = theme.colorScheme.outline;
    final effectiveIcon =
        selected ? (item.activeIcon ?? item.icon) : item.icon;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => context.go(item.path),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: selected ? activeBg : null,
            ),
            child: Row(
              children: [
                Icon(
                  effectiveIcon,
                  size: 22,
                  color: selected ? activeAccent : inactiveColor,
                ),
                const SizedBox(width: 12),
                Text(
                  item.label,
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
