import 'package:flutter/material.dart';

class ChildrenEmptyState extends StatelessWidget {
  const ChildrenEmptyState({super.key, required this.onClear});
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.35)),
      ),
      child: Column(children: [
        Icon(Icons.child_care_outlined,
            size: 48,
            color: theme.colorScheme.outline.withValues(alpha: 0.4)),
        const SizedBox(height: 12),
        Text('Nu există copii cu filtrele aplicate.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.outline)),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: onClear,
          icon: const Icon(Icons.close_rounded, size: 16),
          label: const Text('Șterge filtrele'),
        ),
      ]),
    );
  }
}
