import 'package:flutter/material.dart';

/// Shared card shell for sections on the Child Details page and every
/// other surface that adopts the same chrome (parent dashboard child
/// cards, parent Information centru cards, parent profile/settings
/// cards, …).
///
/// The header row (icon tile + title + trailing) is rendered only when
/// at least one of [title], [iconData] or [trailing] is supplied.
/// Pass all three as null to obtain a body-only card with the same
/// border / radius / padding as every other card in the app (used by
/// the parent About hero so the brand block is the only content
/// inside the card chrome).
class DetailsSectionCard extends StatelessWidget {
  const DetailsSectionCard({
    super.key,
    this.title,
    required this.child,
    this.iconData,
    this.iconColor,
    this.trailing,
  });

  final String? title;
  final Widget child;
  final IconData? iconData;
  final Color? iconColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = iconColor ?? theme.colorScheme.primary;

    final hasTitle = title != null && title!.isNotEmpty;
    final showHeader = hasTitle || iconData != null || trailing != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader) ...[
            Row(
              children: [
                if (iconData != null) ...[
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: effectiveColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(iconData, size: 17, color: effectiveColor),
                  ),
                  const SizedBox(width: 10),
                ],
                if (hasTitle)
                  Expanded(
                    child: Text(
                      title!,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  )
                else
                  const Spacer(),
                ?trailing,
              ],
            ),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }
}
