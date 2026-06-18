import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_providers.dart';
import '../utils/permission_utils.dart';
import 'notification_bell.dart';
import 'user_menu.dart';

// ── Desktop top bar (placed inside the sidebar + content column) ──────────────

class AppDesktopTopBar extends ConsumerWidget {
  const AppDesktopTopBar({
    super.key,
    this.viewAllNotificationRoute = '/notifications',
  });

  /// Route the bell dropdown's "Toate notificările" footer links to.
  /// Defaults to the staff page; parent shells pass
  /// '/parent/notifications'.
  final String viewAllNotificationRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 60,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            // Brand on the left ("TTH Manager"); actions on the right.
            // Page-specific titles live inside the page body — the
            // header title is always the product name.
            child: Row(
              children: [
                Text(
                  'TTH Manager',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    letterSpacing: -0.2,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                AppNotificationBell(viewAllRoute: viewAllNotificationRoute),
                const SizedBox(width: 8),
                profileAsync.when(
                  data: (profile) => AppUserMenu(
                    name: profile?.fullName ?? 'Utilizator',
                    role: roleName(profile?.role ?? ''),
                    onLogout: () =>
                        ref.read(authRepositoryProvider).signOut(),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, thickness: 1),
      ],
    );
  }
}
