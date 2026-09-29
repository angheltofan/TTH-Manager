import 'package:flutter/material.dart';

import 'sidebar_base.dart';
import 'staff_nav_items.dart';

/// Staff left-rail sidebar. Thin wrapper over [AppSidebarBase] that
/// supplies the primary "Dashboard / Copii / Afterschool / Asistent"
/// group, a "CONT" section label, and "Setări" in the trailing group.
///
/// Destinations live in [kStaffPrimaryNav] + [kStaffTrailingNav] so
/// the mobile navigation drawer (in [AppShell]) can reuse them without
/// keeping a parallel list.
class AppSidebar extends StatelessWidget {
  const AppSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppSidebarBase(
      logoSubtitle: 'Tales & Tech HUB',
      items: kStaffPrimaryNav,
      sectionLabel: 'CONT',
      trailingItems: kStaffTrailingNav,
    );
  }
}
