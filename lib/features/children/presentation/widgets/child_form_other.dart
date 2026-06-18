import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import 'child_form_helpers.dart';

class ChildFormOther extends StatelessWidget {
  const ChildFormOther({
    super.key,
    required this.notesCtrl,
    required this.isActive,
    required this.onActiveChanged,
    required this.paymentType,
    required this.onPaymentTypeChanged,
    required this.inputDeco,
  });

  final TextEditingController notesCtrl;
  final bool isActive;
  final ValueChanged<bool> onActiveChanged;

  /// 'paid' or 'free'.
  final String paymentType;
  final ValueChanged<String> onPaymentTypeChanged;
  final InputDecoration inputDeco;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        ChildFormField(
          label: 'Tip participare',
          required: true,
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(
                value: 'paid',
                label: Text('Plătitor'),
                icon: Icon(Icons.credit_card_outlined, size: 18),
              ),
              ButtonSegment<String>(
                value: 'free',
                label: Text('Gratuit'),
                icon: Icon(Icons.school_outlined, size: 18),
              ),
            ],
            selected: {paymentType},
            showSelectedIcon: false,
            onSelectionChanged: (selection) {
              if (selection.isEmpty) return;
              onPaymentTypeChanged(selection.first);
            },
            style: ButtonStyle(
              textStyle: WidgetStateProperty.all(
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            paymentType == 'free'
                ? 'Copilul participă gratuit. Atelierele și prezența rămân vizibile, '
                    'dar nu se generează cicluri de plată sau alerte financiare.'
                : 'Copilul participă pe cicluri de 4 ședințe, plătite la finalul fiecărui ciclu.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 14),
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
              activeThumbColor: AppColors.purple,
              onChanged: onActiveChanged,
            ),
          ]),
        ),
      ],
    );
  }
}
