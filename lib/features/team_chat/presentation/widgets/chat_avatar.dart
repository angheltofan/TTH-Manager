import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Tiny circular initials avatar used next to incoming message groups.
/// Sized to match the line-height of the bubble's first text line so the
/// avatar visually anchors at the bubble top without extra padding.
class ChatAvatar extends StatelessWidget {
  const ChatAvatar({super.key, required this.initials});
  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: AppColors.purple.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: AppColors.purple,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
