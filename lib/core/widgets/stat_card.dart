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
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? color;
  final String? subLabel;
  final String? trend;
  final VoidCallback? onTap;

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
        final double valueFs = compact ? 20 : 24;
        final double labelFs = compact ? 11 : 13;
        final double subFs = compact ? 10 : 11;
        final double cardHeight = compact ? 110 : 96;

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
                            fontWeight: FontWeight.w700,
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

