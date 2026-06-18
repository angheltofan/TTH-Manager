import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_providers.dart';
import '../utils/permission_utils.dart';
import 'notification_bell.dart';
import 'user_menu.dart';

// ── Page title helper ─────────────────────────────────────────────────────────

String titleForPath(String path) {
  // Parent portal routes — checked first so `/parent/notifications`
  // doesn't get swallowed by the `/notifications` branch below.
  if (path == '/parent') return 'Dashboard';
  if (path.startsWith('/parent/notifications')) return 'Notificări';
  if (path.startsWith('/parent/profile')) return 'Setări';
  if (path.startsWith('/parent/about')) return 'Informații centru';
  // Staff routes.
  if (path.startsWith('/workshops')) return 'Ateliere';
  if (path.startsWith('/children')) return 'Copii';
  if (path.startsWith('/trainers')) return 'Traineri';
  if (path.startsWith('/settings')) return 'Setări';
  if (path.startsWith('/notifications')) return 'Notificări';
  return 'Dashboard';
}

// Breakpoints
const _kMobileBreakpoint = 600.0;

// ── Mobile / tablet top app bar ───────────────────────────────────────────────

class AppTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    this.viewAllNotificationRoute = '/notifications',
  });

  /// Route the bell dropdown's "Toate notificările" footer links to.
  /// Defaults to the staff page; parent shells pass
  /// '/parent/notifications'.
  final String viewAllNotificationRoute;

  /// Toolbar height (56) + bottom divider (1).
  @override
  Size get preferredSize => const Size.fromHeight(57);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final isMobile = MediaQuery.of(context).size.width < _kMobileBreakpoint;

    // Header title is the product name; page-specific titles live in
    // the page content so there is no duplication.
    return AppBar(
      toolbarHeight: 56,
      title: const Text(
        'TTH Manager',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 17,
          letterSpacing: -0.2,
        ),
      ),
      elevation: 0,
      actions: [
        AppNotificationBell(viewAllRoute: viewAllNotificationRoute),
        profileAsync.when(
          data: (profile) => AppUserMenu(
            name: profile?.fullName ?? 'Utilizator',
            role: roleName(profile?.role ?? ''),
            onLogout: () => ref.read(authRepositoryProvider).signOut(),
            // On mobile only avatar is shown; name/role/logout move to popup.
            compact: isMobile,
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),
        const SizedBox(width: 4),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, thickness: 1),
      ),
    );
  }
}
