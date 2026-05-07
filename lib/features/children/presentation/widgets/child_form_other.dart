import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import 'child_form_helpers.dart';

class ChildFormOther extends StatelessWidget {
  const ChildFormOther({
    super.key,
    required this.notesCtrl,
    required this.isActive,
    required this.onActiveChanged,
    required this.inputDeco,
  });

  final TextEditingController notesCtrl;
  final bool isActive;
  final ValueChanged<bool> onActiveChanged;
  final InputDecoration inputDeco;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        ChildFormField(
          label: 'Observații',
          child: TextFormField(
            controller: notesCtrl,
            decoration: inputDeco.copyWith(
                hintText: 'Notițe despre copil…'),
            maxLines: 4,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color:
                    theme.colorScheme.outline.withValues(alpha: 0.4)),
          ),
          child: Row(children: [
            const Icon(Icons.toggle_on_outlined,
                color: AppColors.purple, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Copil activ',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  Text(
                    'Copilul este înscris activ în ateliere',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: isActive,
              activeColor: AppColors.purple,
              onChanged: onActiveChanged,
            ),
          ]),
        ),
      ],
    );
  }
}
