import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color,
    this.subLabel,
    this.trend,
    this.onTap,
    this.dense = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? color;
  final String? subLabel;
  final String? trend;
  final VoidCallback? onTap;

  /// When true, renders the value with a slightly smaller font so
  /// longer string values (e.g. "Luni, 2 iun." on the parent dashboard)
  /// don't truncate. Font weight is unchanged so the visual style
  /// stays identical to the staff dashboard. Default false — staff
  /// dashboard behaviour is unchanged.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final cardColor = color ?? AppColors.purple;
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Compact mode when the cell is narrower than 200 px (2-col on mobile).
        final compact = constraints.maxWidth < 200;

        final double hPad = compact ? 12 : 18;
        final double iconSize = compact ? 40 : 46;
        final double iconInner = compact ? 19 : 22;
        final double gap = compact ? 10 : 14;
        // `dense` shrinks the value font by ~3 px on wide cells so a
        // longer-than-numeric headline (parent "Următorul atelier",
        // "În regulă", etc.) has room to breathe without truncating.
        // Font weight stays at w700 in both modes so the parent and
        // staff dashboards share the same visual hierarchy.
        final double valueFs =
            compact ? 20 : (dense ? 21 : 24);
        final double labelFs = compact ? 11 : 13;
        final double subFs = compact ? 10 : 11;
        final double cardHeight = compact ? 110 : 96;
        const FontWeight valueFw = FontWeight.w700;

        return SizedBox(
          height: cardHeight,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 0),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: iconSize,
                    height: iconSize,
                    decoration: BoxDecoration(
                      color: cardColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(compact ? 10 : 12),
                    ),
                    child: Icon(
                      icon ?? Icons.bar_chart_outlined,
                      color: cardColor,
                      size: iconInner,
                    ),
                  ),
                  SizedBox(width: gap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          value,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: valueFs,
                            fontWeight: valueFw,
                            letterSpacing: -0.5,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          label,
                          style: TextStyle(
                            color: theme.colorScheme.outline,
                            fontSize: labelFs,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subLabel != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subLabel!,
                            style: TextStyle(
                              color: cardColor.withValues(alpha: 0.85),
                              fontSize: subFs,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

