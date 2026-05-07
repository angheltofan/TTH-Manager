import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class ChildrenPaginationRow extends StatelessWidget {
  const ChildrenPaginationRow({
    super.key,
    required this.page,
    required this.totalPages,
    required this.onPageChanged,
  });
  final int page;
  final int totalPages;
  final void Function(int) onPageChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = <int>[];
    if (totalPages <= 7) {
      visible.addAll(List.generate(totalPages, (i) => i));
    } else {
      visible.add(0);
      if (page > 2) visible.add(-1);
      for (var i = (page - 1).clamp(1, totalPages - 2);
          i <= (page + 1).clamp(1, totalPages - 2);
          i++) {
        visible.add(i);
      }
      if (page < totalPages - 3) visible.add(-1);
      visible.add(totalPages - 1);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _PBtn(
            icon: Icons.chevron_left_rounded,
            onTap: page > 0 ? () => onPageChanged(page - 1) : null),
        const SizedBox(width: 4),
        ...visible.map((p) {
          if (p == -1) {
            return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('…',
                    style: TextStyle(color: theme.colorScheme.outline)));
          }
          final sel = p == page;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: GestureDetector(
              onTap: () => onPageChanged(p),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: sel ? AppColors.purple : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: sel
                      ? null
                      : Border.all(
                          color: theme.colorScheme.outline
                              .withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Text('${p + 1}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: sel
                            ? Colors.white
                            : theme.colorScheme.onSurface,
                      )),
                ),
              ),
            ),
          );
        }),
        const SizedBox(width: 4),
        _PBtn(
            icon: Icons.chevron_right_rounded,
            onTap: page < totalPages - 1
                ? () => onPageChanged(page + 1)
                : null),
      ],
    );
  }
}

class _PBtn extends StatelessWidget {
  const _PBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context)
                .colorScheme
                .outline
                .withValues(alpha: disabled ? 0.15 : 0.3),
          ),
        ),
        child: Icon(icon,
            size: 18,
            color: disabled
                ? Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.4)
                : Theme.of(context).colorScheme.onSurface),
      ),
    );
  }
}
