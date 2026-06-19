import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Slim "Mesaje noi" divider rendered between read and unread messages.
/// Single thin brand-tinted line + a centered tag — keeps the marker
/// visible without consuming vertical density.
class ChatNewMessagesDivider extends StatelessWidget {
  const ChatNewMessagesDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: AppColors.purple.withValues(alpha: 0.28),
              thickness: 0.8,
              height: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Mesaje noi',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.purple,
                fontWeight: FontWeight.w700,
                fontSize: 10,
                letterSpacing: 0.4,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: AppColors.purple.withValues(alpha: 0.28),
              thickness: 0.8,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
