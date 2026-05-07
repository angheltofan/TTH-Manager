import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/children_providers.dart';

class ChildrenInfoRow extends ConsumerWidget {
  const ChildrenInfoRow({
    super.key,
    required this.rangeStart,
    required this.rangeEnd,
    required this.total,
    required this.pageSize,
    required this.isWide,
  });

  final int rangeStart, rangeEnd, total, pageSize;
  final bool isWide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final labelStyle =
        theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline);
    return Row(children: [
      Text('Afișează $rangeStart–$rangeEnd din $total copii',
          style: labelStyle),
      const Spacer(),
      if (isWide) ...[
        Text('Pe pagină:', style: labelStyle),
        const SizedBox(width: 8),
        DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: pageSize,
            isDense: true,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurface),
            items: [10, 20, 50]
                .map((v) => DropdownMenuItem(
                    value: v,
                    child: Text('$v / pagină',
                        style: const TextStyle(fontSize: 13))))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                ref.read(childrenPageSizeProvider.notifier).state = v;
                ref.read(childrenPageProvider.notifier).state = 0;
              }
            },
          ),
        ),
      ],
    ]);
  }
}
