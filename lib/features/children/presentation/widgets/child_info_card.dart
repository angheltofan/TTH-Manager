import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/initials_avatar.dart';
import '../../domain/child_model.dart';

class ChildInfoCard extends StatelessWidget {
  const ChildInfoCard({
    super.key,
    required this.child,
    required this.isAdmin,
    this.workshopType,
  });

  final ChildModel child;
  final bool isAdmin;
  final String? workshopType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = child.isActive == true;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Avatar + name + edit ──────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ChildAvatar(name: child.fullName, size: 52, workshopType: workshopType),
              const SizedBox(width: 14),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        child.fullName,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(isActive: isActive),
                    if (isAdmin) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined,
                            color: AppColors.purple, size: 17),
                        onPressed: () => GoRouter.of(context)
                            .go('/children/${child.id}/edit'),
                        tooltip: 'Editează',
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // ── Info chips row ────────────────────────────────────────────
          Wrap(
            spacing: 24,
            runSpacing: 10,
            children: [
              if (child.birthDate != null)
                _InfoChip(
                  icon: Icons.cake_outlined,
                  label: 'Data nașterii',
                  value: formatDate(child.birthDate!),
                ),
              if (child.age != null)
                _InfoChip(
                  icon: Icons.person_outline_rounded,
                  label: 'Vârstă',
                  value: '${child.age} ani',
                ),
              _InfoChip(
                icon: Icons.supervisor_account_outlined,
                label: 'Nume părinte',
                value: (child.parentName != null &&
                        child.parentName!.isNotEmpty)
                    ? child.parentName!
                    : '—',
              ),
              if (child.parentPhone != null)
                _InfoChip(
                  icon: Icons.phone_outlined,
                  label: 'Telefon părinte',
                  value: child.parentPhone!,
                ),
              if (child.notes != null && child.notes!.isNotEmpty)
                _InfoChip(
                  icon: Icons.notes_outlined,
                  label: 'Observații',
                  value: child.notes!,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Status badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isActive});
  final bool isActive;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: (isActive ? AppColors.success : AppColors.muted)
              .withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          isActive ? 'Activ' : 'Inactiv',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isActive ? AppColors.success : AppColors.muted,
          ),
        ),
      );
}

// ── Info chip: icon + label + value ──────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  const _InfoChip(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon,
            size: 15,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.45)),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
