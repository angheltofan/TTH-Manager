import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shared visual chrome for the "left-column selector cards" pattern
/// used on the Child Details page — one card per selectable item
/// (workshop series, Afterschool program, …) with a purple highlight
/// when picked.
///
/// The shell is deliberately **presentation-only** — it owns padding,
/// border-radius, selected/unselected border + fill, and the tap
/// affordance. The body is caller-supplied so every feature keeps
/// full control over its own content while sharing the same look.
///
/// Recipe (matches the existing inline `_SelectorCard` in
/// [current_tab.dart] used by the workshop side):
///   • padding: 14
///   • radius:  12
///   • bg (selected):     `AppColors.purple α 0.06`
///   • bg (unselected):   `theme.cardTheme.color`
///   • border (selected): `AppColors.purple` @ 1.5px
///   • border (else):     `theme.colorScheme.outline α 0.2` @ 1px
class SelectorCardShell extends StatelessWidget {
  const SelectorCardShell({
    super.key,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.purple.withValues(alpha: 0.06)
                : theme.cardTheme.color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppColors.purple
                  : theme.colorScheme.outline.withValues(alpha: 0.2),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
