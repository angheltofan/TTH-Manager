import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Grid of suggested prompts shown on the assistant empty state. Tapping
/// a chip auto-sends the prompt through [onPick]. Hidden as soon as the
/// conversation has at least one message (the parent gates visibility).
class AssistantQuickPrompts extends StatelessWidget {
  const AssistantQuickPrompts({
    super.key,
    required this.prompts,
    required this.onPick,
    this.disabled = false,
  });

  /// The default prompt set, in the order the spec lists them.
  static const List<String> defaultPrompts = <String>[
    'Ce probleme avem azi?',
    'Cine are plăți neconfirmate?',
    'Ce copii necesită atenție?',
    'Care este planul săptămânii?',
    'Ce date lipsă avem în aplicație?',
    'Care atelier are cele mai multe absențe?',
    'Ce oportunități de creștere observi?',
  ];

  final List<String> prompts;
  final Future<void> Function(String prompt) onPick;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'EXEMPLE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.outline,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in prompts)
              _PromptChip(
                label: p,
                onTap: disabled ? null : () => onPick(p),
              ),
          ],
        ),
      ],
    );
  }
}

class _PromptChip extends StatelessWidget {
  const _PromptChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.purple
              .withValues(alpha: onTap == null ? 0.04 : 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.purple
                .withValues(alpha: onTap == null ? 0.15 : 0.25),
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.purple,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
