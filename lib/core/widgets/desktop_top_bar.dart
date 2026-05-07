import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_providers.dart';
import '../utils/permission_utils.dart';
import 'app_top_bar.dart';
import 'notification_bell.dart';
import 'user_menu.dart';

// ── Desktop top bar (placed inside the sidebar + content column) ──────────────

class AppDesktopTopBar extends ConsumerWidget {
  const AppDesktopTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = GoRouterState.of(context).uri.path;
    final profileAsync = ref.watch(currentProfileProvider);
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 60,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Text(
                  titleForPath(path),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                const AppNotificationBell(),
                const SizedBox(width: 8),
                profileAsync.when(
                  data: (profile) => AppUserMenu(
                    name: profile?.fullName ?? 'Utilizator',
                    role: roleName(profile?.role ?? ''),
                    onLogout: () =>
                        ref.read(authRepositoryProvider).signOut(),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
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
