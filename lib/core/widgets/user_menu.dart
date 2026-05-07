import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// User menu widget.
///
/// - [compact] = false (default): full chip with avatar, name, role + logout
///   button. Used on desktop.
/// - [compact] = true: avatar-only circle that opens a popup menu with name,
///   role, and logout option. Used on mobile top bar.
class AppUserMenu extends StatelessWidget {
  const AppUserMenu({
    super.key,
    required this.name,
    required this.role,
    required this.onLogout,
    this.compact = false,
  });

  final String name;
  final String role;
  final VoidCallback onLogout;

  /// When true, renders as an avatar-only button that opens a popup menu.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _CompactAvatarMenu(name: name, role: role, onLogout: onLogout);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: AppColors.purple.withValues(alpha: 0.15),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(
              color: AppColors.purple,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            if (role.isNotEmpty)
              Text(
                role,
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
          ],
        ),
        IconButton(
          onPressed: onLogout,
          icon: const Icon(Icons.logout_rounded, size: 18),
          color: AppColors.muted,
          tooltip: 'Deconectare',
        ),
      ],
    );
  }
}

// ── Compact avatar with popup menu (mobile) ───────────────────────────────────

enum _UserMenuAction { logout }

class _CompactAvatarMenu extends StatelessWidget {
  const _CompactAvatarMenu({
    required this.name,
    required this.role,
    required this.onLogout,
  });

  final String name;
  final String role;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return PopupMenuButton<_UserMenuAction>(
      offset: const Offset(0, 50),
      tooltip: name,
      onSelected: (action) {
        if (action == _UserMenuAction.logout) onLogout();
      },
      itemBuilder: (_) => [
        // Non-interactive header: name + role
        PopupMenuItem<_UserMenuAction>(
          enabled: false,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              if (role.isNotEmpty)
                Text(
                  role,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                  ),
                ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<_UserMenuAction>(
          value: _UserMenuAction.logout,
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 18),
              SizedBox(width: 10),
              Text('Deconectare'),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.purple.withValues(alpha: 0.15),
          child: Text(
            initial,
            style: const TextStyle(
              color: AppColors.purple,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
