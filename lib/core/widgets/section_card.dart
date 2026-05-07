import 'package:flutter/material.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.padding,
    this.expanded = false,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  /// When true the card fills its parent height and the child area expands
  /// to consume remaining space (use with a scrollable child).
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final childPadding = Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: child,
    );

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          if (expanded) Expanded(child: childPadding) else childPadding,
        ],
      ),
    );
  }
}

