import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Compact user chip showing avatar, name, role, and logout button.
class AppUserMenu extends StatelessWidget {
  const AppUserMenu({
    super.key,
    required this.name,
    required this.role,
    required this.onLogout,
  });

  final String name;
  final String role;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
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
