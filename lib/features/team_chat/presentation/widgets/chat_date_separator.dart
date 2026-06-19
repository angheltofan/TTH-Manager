import 'package:flutter/material.dart';

/// Centered chip-style date separator (Astăzi / Ieri / specific date).
/// No side-divider lines — a subtle pill matches the chat-app convention
/// and keeps the conversation visually dense.
class ChatDateSeparator extends StatelessWidget {
  const ChatDateSeparator({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pillColor = isDark
        ? theme.colorScheme.surface.withValues(alpha: 0.55)
        : theme.colorScheme.surface.withValues(alpha: 0.85);
    final borderColor =
        theme.colorScheme.outline.withValues(alpha: isDark ? 0.18 : 0.22);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: pillColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: 0.7),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
              fontWeight: FontWeight.w600,
              fontSize: 10.5,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}
