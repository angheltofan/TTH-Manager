import 'package:flutter/material.dart';

import 'sidebar_base.dart';

/// Staff left-rail sidebar. Thin wrapper over [AppSidebarBase] that
/// supplies the primary "Dashboard / Copii / Asistent" group, a "CONT"
/// section label, and "Setări" in the trailing group. Trainer
/// administration moved from the sidebar to Setări → Echipa centrului.
class AppSidebar extends StatelessWidget {
  const AppSidebar({super.key});

  static const _primary = <SidebarNavItem>[
    SidebarNavItem(
      icon: Icons.space_dashboard_outlined,
      label: 'Dashboard',
      path: '/dashboard',
    ),
    SidebarNavItem(
      icon: Icons.groups_outlined,
      label: 'Copii',
      path: '/children',
    ),
    SidebarNavItem(
      icon: Icons.auto_awesome_outlined,
      label: 'Asistent',
      path: '/assistant',
    ),
  ];

  static const _trailing = <SidebarNavItem>[
    SidebarNavItem(
      icon: Icons.tune_outlined,
      label: 'Setări',
      path: '/settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return const AppSidebarBase(
      logoSubtitle: 'Tales & Tech HUB',
      items: _primary,
      sectionLabel: 'CONT',
      trailingItems: _trailing,
    );
  }
}
