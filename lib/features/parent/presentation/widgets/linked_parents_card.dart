import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../children/presentation/widgets/details_section_card.dart';
import '../../domain/parent_link.dart';
import '../../providers/parent_links_providers.dart';
import 'add_parent_dialog.dart';

/// Admin-only card on the Child Details page that lists the parents
/// linked to the current child via `public.child_parents`.
///
/// Visibility in P4: admin only (mounted by the parent page only when
/// `currentProfileProvider.valueOrNull?.isAdmin == true`). Trainer
/// read-only access requires an RLS extension on `child_parents` and
/// `profiles` — tracked as a P4.5 follow-up.
class LinkedParentsCard extends ConsumerWidget {
  const LinkedParentsCard({super.key, required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin =
        ref.watch(currentProfileProvider).valueOrNull?.isAdmin ?? false;
    final linksAsync = ref.watch(linkedParentsProvider(childId));
    final theme = Theme.of(context);

    final trailing = isAdmin
        ? TextButton.icon(
            onPressed: () => _openAddDialog(context, ref),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Adaugă părinte'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.purple,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          )
        : null;

    return DetailsSectionCard(
      title: 'Părinți asociați',
      iconData: Icons.family_restroom_rounded,
      iconColor: const Color(0xFFEC4899),
      trailing: trailing,
      child: linksAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        error: (e, _) => AppError(message: e.toString()),
        data: (links) {
          if (links.isEmpty) {
            return Text(
              'Nu există părinți asociați.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < links.length; i++) ...[
                if (i > 0) const Divider(height: 20),
                _LinkRow(
                  link: links[i],
                  isAdmin: isAdmin,
                  onRemove: () => _removeLink(context, ref, links[i]),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _openAddDialog(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AddParentDialog(childId: childId),
    );
    if (ok == true) {
      ref.invalidate(linkedParentsProvider(childId));
    }
  }

  Future<void> _removeLink(
      BuildContext context, WidgetRef ref, ParentLink link) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimină asocierea'),
        content: Text(
          'Elimini asocierea cu ${link.fullName.isEmpty ? "(fără nume)" : link.fullName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Anulează'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimină'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final isAdmin =
        ref.read(currentProfileProvider).valueOrNull?.isAdmin ?? false;
    try {
      await ref
          .read(parentLinksRepositoryProvider)
          .unlinkParent(isAdmin: isAdmin, linkId: link.id);
      ref.invalidate(linkedParentsProvider(childId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Asociere eliminată: ${link.fullName.isEmpty ? "părinte" : link.fullName}.',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage(e))),
        );
      }
    }
  }

  static String _errorMessage(Object e) {
    final s = e.toString();
    if (s.contains('42501') || s.contains('403') || s.contains('permission')) {
      return 'Permisiune insuficientă.';
    }
    return 'Eroare: $e';
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.link,
    required this.isAdmin,
    required this.onRemove,
  });

  final ParentLink link;
  final bool isAdmin;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      link.fullName.isEmpty ? '(fără nume)' : link.fullName,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (link.isPrimary) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.purple.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Primar',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.purple,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (link.relationship != null &&
                  link.relationship!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  link.relationship!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ],
            ],
          ),
        ),
        if (isAdmin)
          TextButton(
            onPressed: onRemove,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: const Text('Elimină'),
          ),
      ],
    );
  }
}
