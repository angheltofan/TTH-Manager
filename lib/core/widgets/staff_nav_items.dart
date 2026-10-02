import 'package:flutter/material.dart';

import 'sidebar_base.dart';

/// Single source of truth for the staff shell's navigation
/// destinations. Consumed by:
///   • [AppSidebar]  — desktop left-rail (uses [kStaffPrimaryNav] +
///                     [kStaffTrailingNav] to preserve the "CONT"
///                     divider label between the two groups);
///   • [AppShell]    — mobile / tablet navigation drawer (uses the
///                     flat [kStaffAllNav]).
///
/// Do not duplicate these lists elsewhere.
const List<SidebarNavItem> kStaffPrimaryNav = <SidebarNavItem>[
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
    icon: Icons.school_outlined,
    label: 'Afterschool',
    path: '/afterschool',
  ),
  SidebarNavItem(
    icon: Icons.rocket_launch_outlined,
    label: 'Demo-uri',
    path: '/demos',
  ),
  SidebarNavItem(
    icon: Icons.auto_awesome_outlined,
    label: 'Asistent',
    path: '/assistant',
  ),
];

const List<SidebarNavItem> kStaffTrailingNav = <SidebarNavItem>[
  SidebarNavItem(
    icon: Icons.tune_outlined,
    label: 'Setări',
    path: '/settings',
  ),
];

const List<SidebarNavItem> kStaffAllNav = <SidebarNavItem>[
  ...kStaffPrimaryNav,
  ...kStaffTrailingNav,
];
