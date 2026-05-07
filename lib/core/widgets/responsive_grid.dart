import 'package:flutter/material.dart';

class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 220,
    this.spacing = 16,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth.isFinite ? constraints.maxWidth : 600.0;
        final columns =
            (w / (minItemWidth + spacing)).floor().clamp(1, 6).toInt();
        return _GridLayout(
          columns: columns,
          spacing: spacing,
          children: children,
        );
      },
    );
  }
}

class _GridLayout extends StatelessWidget {
  const _GridLayout({
    required this.columns,
    required this.spacing,
    required this.children,
  });

  final int columns;
  final double spacing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      final rowChildren = <Widget>[];
      for (var j = i; j < i + columns && j < children.length; j++) {
        rowChildren.add(Expanded(child: children[j]));
        if (j < i + columns - 1 && j < children.length - 1) {
          rowChildren.add(SizedBox(width: spacing));
        }
      }
      // Fill remaining slots
      final remaining = columns - rowChildren.whereType<Expanded>().length;
      for (var k = 0; k < remaining; k++) {
        rowChildren.add(const Expanded(child: SizedBox.shrink()));
      }
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rowChildren,
      ));
      if (i + columns < children.length) {
        rows.add(SizedBox(height: spacing));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows,
    );
  }
}
