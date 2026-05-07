import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

// ── Shared input decoration ───────────────────────────────────────────────────

InputDecoration workshopInputDecoration(ThemeData theme) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide:
        BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.4)),
  );
  return InputDecoration(
    filled: true,
    fillColor: theme.scaffoldBackgroundColor,
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: AppColors.purple, width: 1.5)),
    errorBorder: border.copyWith(
        borderSide: const BorderSide(color: AppColors.error, width: 1.5)),
    focusedErrorBorder: border.copyWith(
        borderSide: const BorderSide(color: AppColors.error, width: 1.5)),
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );
}

// ── Form field label wrapper ──────────────────────────────────────────────────

class WorkshopFormField extends StatelessWidget {
  const WorkshopFormField({
    super.key,
    required this.label,
    required this.child,
    this.required = false,
  });

  final String label;
  final Widget child;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          if (required)
            const Text(' *',
                style: TextStyle(color: AppColors.error, fontSize: 12)),
        ]),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

// ── Basic info section (title + notes) ───────────────────────────────────────

class WorkshopBasicInfoSection extends StatelessWidget {
  const WorkshopBasicInfoSection({
    super.key,
    required this.titleCtrl,
    required this.notesCtrl,
  });

  final TextEditingController titleCtrl;
  final TextEditingController notesCtrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WorkshopFormField(
          label: 'Titlu',
          required: true,
          child: TextFormField(
            controller: titleCtrl,
            decoration: workshopInputDecoration(theme),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Titlul este obligatoriu' : null,
          ),
        ),
        const SizedBox(height: 16),
        WorkshopFormField(
          label: 'Observații',
          child: TextFormField(
            controller: notesCtrl,
            decoration: workshopInputDecoration(theme).copyWith(hintText: 'Opțional'),
            maxLines: 3,
          ),
        ),
      ],
    );
  }
}
