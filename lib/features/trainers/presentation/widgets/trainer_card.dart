import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/trainer_profile.dart';

class TrainerCard extends StatelessWidget {
  const TrainerCard({super.key, required this.trainer});

  final TrainerProfile trainer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAdmin = trainer.role == 'admin';
    final accent = isAdmin ? AppColors.purple : AppColors.info;

    // Two-letter initials: first char of first name + first char of last name.
    final initials = [
      trainer.firstName.isNotEmpty ? trainer.firstName[0] : '',
      trainer.lastName.isNotEmpty ? trainer.lastName[0] : '',
    ].join().toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.go('/trainers/${trainer.id}'),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                // ── Avatar with initials ─────────────────────────────
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: accent,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // ── Name + role badge ────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trainer.fullName,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isAdmin ? 'Administrator' : 'Trainer',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Active series count ──────────────────────────────
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${trainer.workshopsCount}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.purple,
                      ),
                    ),
                    Text(
                      'serii active',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded,
                    color: theme.colorScheme.outline, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
