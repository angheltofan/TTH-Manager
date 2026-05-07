import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_buttons.dart';

// ── Recurring scope enum ──────────────────────────────────────────────────────

enum RecurringScope { thisOnly, series }

// ── Workshop form actions (toggles + scope picker + save button) ───────────────

class WorkshopFormActions extends StatelessWidget {
  const WorkshopFormActions({
    super.key,
    required this.isActive,
    required this.isRecurring,
    required this.onActiveChanged,
    required this.onRecurringChanged,
    required this.isEditing,
    required this.hasRecurringSeries,
    required this.applyScope,
    required this.onScopeChanged,
    required this.saving,
    required this.onSave,
    required this.saveLabel,
  });

  final bool isActive;
  final bool isRecurring;
  final ValueChanged<bool> onActiveChanged;
  final ValueChanged<bool> onRecurringChanged;
  final bool isEditing;
  final bool hasRecurringSeries;
  final RecurringScope applyScope;
  final ValueChanged<RecurringScope> onScopeChanged;
  final bool saving;
  final VoidCallback? onSave;
  final String saveLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WorkshopToggleTile(
          label: 'Activ',
          subtitle: 'Atelierul apare în lista activă',
          value: isActive,
          onChanged: onActiveChanged,
        ),
        const SizedBox(height: 8),
        _WorkshopToggleTile(
          label: 'Recurent',
          subtitle: 'Atelierul face parte dintr-o serie recurentă',
          value: isRecurring,
          onChanged: onRecurringChanged,
        ),
        if (isEditing && hasRecurringSeries) ...[
          const SizedBox(height: 16),
          _RecurringScopePicker(
            value: applyScope,
            onChanged: onScopeChanged,
          ),
        ],
        const SizedBox(height: 32),
        AppPrimaryButton(
          label: saveLabel,
          icon: Icons.check_rounded,
          loading: saving,
          fullWidth: true,
          onPressed: onSave,
        ),
      ],
    );
  }
}

// ── Toggle tile ───────────────────────────────────────────────────────────────

class _WorkshopToggleTile extends StatelessWidget {
  const _WorkshopToggleTile({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.3)),
        color: theme.cardTheme.color,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.purple,
          ),
        ],
      ),
    );
  }
}

// ── Recurring scope picker ────────────────────────────────────────────────────

class _RecurringScopePicker extends StatelessWidget {
  const _RecurringScopePicker({
    required this.value,
    required this.onChanged,
  });

  final RecurringScope value;
  final ValueChanged<RecurringScope> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.3)),
        color: theme.cardTheme.color,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Text(
              'Aplică modificările',
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          _ScopeTile(
            label: 'Doar acestei instanțe',
            subtitle: 'Modifică numai atelierul curent',
            selected: value == RecurringScope.thisOnly,
            onTap: () => onChanged(RecurringScope.thisOnly),
          ),
          Divider(
            height: 1,
            indent: 14,
            endIndent: 14,
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
          _ScopeTile(
            label: 'Seriei recurente',
            subtitle: 'Modifică toate atelierele viitoare din această serie',
            selected: value == RecurringScope.series,
            onTap: () => onChanged(RecurringScope.series),
          ),
        ],
      ),
    );
  }
}

class _ScopeTile extends StatelessWidget {
  const _ScopeTile({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 20,
              color:
                  selected ? AppColors.purple : theme.colorScheme.outline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: selected ? AppColors.purple : null,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
