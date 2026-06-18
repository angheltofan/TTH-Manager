import 'package:flutter/material.dart';

import '../../../../core/widgets/sidebar_base.dart';

/// Parent left-rail sidebar. Thin wrapper over [AppSidebarBase] that
/// supplies the three top-level parent destinations. Icons and label
/// typography mirror the staff `AppSidebar` exactly (no `activeIcon`
/// override — the active state is the same outline icon recoloured by
/// `AppSidebarBase`) so both shells share one visual language.
///
/// Order matches the menu spec: Dashboard → Informații centru → Setări.
/// Logout is intentionally NOT in the sidebar — it lives in the Setări
/// page's "Sesiune" card, single source of truth across roles.
class ParentSidebar extends StatelessWidget {
  const ParentSidebar({super.key});

  static const _items = <SidebarNavItem>[
    SidebarNavItem(
      icon: Icons.space_dashboard_outlined,
      label: 'Dashboard',
      path: '/parent',
    ),
    SidebarNavItem(
      icon: Icons.info_outlined,
      label: 'Informații centru',
      path: '/parent/info',
    ),
    SidebarNavItem(
      icon: Icons.tune_outlined,
      label: 'Setări',
      path: '/parent/settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return const AppSidebarBase(
      logoSubtitle: 'Tales & Tech HUB',
      items: _items,
    );
  }
}
