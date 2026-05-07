import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_providers.dart';
import '../utils/permission_utils.dart';
import 'notification_bell.dart';
import 'user_menu.dart';

// ── Page title helper ─────────────────────────────────────────────────────────

String titleForPath(String path) {
  if (path.startsWith('/workshops')) return 'Ateliere';
  if (path.startsWith('/children')) return 'Copii';
  if (path.startsWith('/trainers')) return 'Traineri';
  if (path.startsWith('/settings')) return 'Setări';
  if (path.startsWith('/notifications')) return 'Notificări';
  return 'Dashboard';
}

// ── Mobile / tablet top app bar ───────────────────────────────────────────────

class AppTopBar extends ConsumerWidget implements PreferredSizeWidget {
  const AppTopBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = GoRouterState.of(context).uri.path;
    final profileAsync = ref.watch(currentProfileProvider);

    return AppBar(
      title: Text(
        titleForPath(path),
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
      ),
      elevation: 0,
      actions: [
        const AppNotificationBell(),
        profileAsync.when(
          data: (profile) => AppUserMenu(
            name: profile?.fullName ?? 'Utilizator',
            role: roleName(profile?.role ?? ''),
            onLogout: () => ref.read(authRepositoryProvider).signOut(),
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
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
