import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/workshops_providers.dart';
import 'workshop_basic_info_section.dart';

// ── Trainer section ───────────────────────────────────────────────────────────
//
// Watches [trainersForDropdownProvider] internally so that a data refresh only
// rebuilds this widget — not the entire form page.

class WorkshopTrainerSection extends ConsumerWidget {
  const WorkshopTrainerSection({
    super.key,
    required this.trainerId,
    required this.onTrainerChanged,
    required this.onTrainerReset,
  });

  final String? trainerId;
  final ValueChanged<String?> onTrainerChanged;

  /// Called with the corrected value when the loaded [trainerId] does not
  /// exist in the dropdown list (e.g. the trainer was deleted).
  final ValueChanged<String?> onTrainerReset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final trainersAsync = ref.watch(trainersForDropdownProvider);

    return WorkshopFormField(
      label: 'Trainer',
      required: true,
      child: trainersAsync.when(
        loading: () => _loadingBox(theme),
        error: (e, _) => Text('Eroare: $e',
            style: TextStyle(color: theme.colorScheme.error)),
        data: (trainers) {
          final validIds = trainers.map((t) => t.id).toSet();
          final safeId =
              (trainerId != null && validIds.contains(trainerId))
                  ? trainerId
                  : null;
          if (safeId != trainerId) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              onTrainerReset(safeId);
            });
          }
          return DropdownButtonFormField<String>(
            value: safeId,
            decoration: workshopInputDecoration(theme),
            hint: const Text('Selectează trainer'),
            items: trainers
                .map((t) => DropdownMenuItem(
                      value: t.id,
                      child: Text(t.displayName),
                    ))
                .toList(),
            onChanged: onTrainerChanged,
            validator: (v) =>
                v == null ? 'Selectează un trainer' : null,
          );
        },
      ),
    );
  }

  Widget _loadingBox(ThemeData theme) => Container(
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.4)),
        ),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
}
