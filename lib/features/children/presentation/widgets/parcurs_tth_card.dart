import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../domain/child_model.dart';
import 'level_progress_dialog.dart';

/// Compact section on the Child Details page that displays — and,
/// for staff, lets admin + trainer edit — `children.current_level`
/// and `children.level_progress`.
///
/// Parents never see this widget (the Parent Portal is a separate
/// stack); staff see it with an "Editează" button that opens
/// [LevelProgressDialog]. The write path is a SECURITY DEFINER RPC
/// (`set_child_learning_level`), so a non-staff caller is refused by
/// Postgres regardless of what this widget renders.
///
/// NULL / NULL means "not placed yet" — the card renders explicit
/// placeholders instead of silently defaulting to Explorer 0%, as
/// agreed in the Phase 1 schema design.
class ParcursTthCard extends ConsumerWidget {
  const ParcursTthCard({super.key, required this.child});

  final ChildModel child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isStaff =
        ref.watch(currentProfileProvider).valueOrNull?.isStaff ?? false;

    final level = child.currentLevel;
    final progress = child.levelProgress;

    final hasLevel = level != null && level.isNotEmpty;
    final hasProgress = progress != null;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.auto_graph_rounded,
                    size: 16,
                    color: AppColors.info,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Parcurs TTH',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (isStaff)
                  TextButton.icon(
                    onPressed: () => _openEditor(context),
                    icon: const Icon(Icons.edit_outlined, size: 15),
                    label: const Text('Editează'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.info,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _LevelLine(
              label: 'Nivel curent',
              value: hasLevel ? level : 'Nivel neatribuit',
              isPlaceholder: !hasLevel,
            ),
            const SizedBox(height: 12),
            _ProgressLine(progress: progress, hasProgress: hasProgress),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditor(BuildContext context) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => LevelProgressDialog(
        childId: child.id,
        childFullName: child.fullName,
        initialLevel: child.currentLevel,
        initialProgress: child.levelProgress,
      ),
    );
  }
}

class _LevelLine extends StatelessWidget {
  const _LevelLine({
    required this.label,
    required this.value,
    required this.isPlaceholder,
  });

  final String label;
  final String value;
  final bool isPlaceholder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: isPlaceholder
                ? theme.colorScheme.outline
                : theme.textTheme.bodyMedium?.color,
            fontStyle: isPlaceholder ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ],
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.progress, required this.hasProgress});

  final int? progress;
  final bool hasProgress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            'Progres nivel',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
        Expanded(
          child: hasProgress
              ? Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: (progress! / 100).clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: AppColors.info.withValues(
                            alpha: 0.12,
                          ),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.info,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$progress%',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                )
              : Text(
                  'Progres neatribuit',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline,
                    fontStyle: FontStyle.italic,
                  ),
                ),
        ),
      ],
    );
  }
}
