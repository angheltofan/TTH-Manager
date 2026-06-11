import 'package:flutter/material.dart';

import '../../../../core/widgets/section_card.dart';
import '../../domain/parent_dashboard.dart';
import 'parent_child_card.dart';

/// "Copiii mei" section on the parent dashboard.
///
/// Wraps a stack (mobile / single-child) or a 2-column grid (wide +
/// ≥ 2 children) of [ParentChildCard] widgets inside a shared
/// [SectionCard]. Pure layout — every visual element comes from
/// shared primitives.
class ParentChildrenSection extends StatelessWidget {
  const ParentChildrenSection({
    super.key,
    required this.children,
    required this.isWide,
  });

  final List<ParentDashboardChild> children;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (children.isEmpty) {
      return SectionCard(
        title: 'Copiii mei',
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Text(
          'Nu există încă niciun copil asociat contului.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    return SectionCard(
      title: 'Copiii mei',
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: _ChildrenLayout(children: children, isWide: isWide),
    );
  }
}

/// Layout primitive: single column on narrow / single-child, paired
/// 2-column rows with `IntrinsicHeight` on wide multi-child.
class _ChildrenLayout extends StatelessWidget {
  const _ChildrenLayout({required this.children, required this.isWide});
  final List<ParentDashboardChild> children;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    if (!isWide || children.length == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            ParentChildCard(child: children[i]),
          ],
        ],
      );
    }

    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      final left = children[i];
      final right = (i + 1 < children.length) ? children[i + 1] : null;
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: ParentChildCard(child: left)),
              const SizedBox(width: 12),
              Expanded(
                child: right == null
                    ? const SizedBox.shrink()
                    : ParentChildCard(child: right),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          rows[i],
        ],
      ],
    );
  }
}
