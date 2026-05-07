import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/workshop_type_helper.dart';
import '../../../../core/widgets/initials_avatar.dart';
import '../../domain/child_row.dart';
import '../../domain/child_workshop_summary.dart';
import '../../providers/children_providers.dart';

// ── Entry (dispatches wide/narrow, owns delete dialog) ────────────────────────

class ChildEntry extends ConsumerWidget {
  const ChildEntry({
    super.key,
    required this.child,
    required this.isWide,
    required this.isAdmin,
    required this.isTrainer,
  });
  final ChildRow child;
  final bool isWide;
  final bool isAdmin;
  final bool isTrainer;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Șterge copilul'),
        content: Text(
            'Ești sigur că vrei să ștergi pe ${child.fullName}?\nAceastă acțiune nu poate fi anulată.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anulează')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Șterge'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(childrenRepositoryProvider).delete(child.id);
      ref.invalidate(allChildrenProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${child.fullName} a fost șters.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Eroare la ștergere: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void onDelete() => _confirmDelete(context, ref);
    if (isWide) return _WideRow(child: child, isAdmin: isAdmin, onDelete: onDelete);
    return _NarrowCard(child: child, isAdmin: isAdmin, onDelete: onDelete);
  }
}

// ── Wide desktop row ──────────────────────────────────────────────────────────

class _WideRow extends StatelessWidget {
  const _WideRow({required this.child, required this.isAdmin, required this.onDelete});
  final ChildRow child;
  final bool isAdmin;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => context.go('/children/${child.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          ChildAvatar(
            name: child.fullName,
            size: 36,
            workshopType: child.workshops.isNotEmpty
                ? child.workshops.first.workshopType
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(flex: 3, child: Text(child.fullName, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
          Expanded(flex: 4, child: _WorkshopBadgeRow(workshops: child.workshops)),
          Expanded(flex: 2, child: child.lastAttDate != null
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(formatDate(child.lastAttDate!), style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
                _AttStatusText(status: child.lastAttStatus),
              ])
            : Text('—', style: TextStyle(color: theme.colorScheme.outline))),
          SizedBox(width: 80, child: _ActiveBadge(isActive: child.isActive)),
          SizedBox(
            width: isAdmin ? 110 : 80,
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              _ActionBtn(icon: Icons.visibility_outlined, color: AppColors.info, tooltip: 'Detalii', onTap: () => context.go('/children/${child.id}')),
              if (isAdmin) ...[
                const SizedBox(width: 4),
                _ActionBtn(icon: Icons.edit_outlined, color: AppColors.warning, tooltip: 'Editează', onTap: () => context.go('/children/${child.id}/edit')),
                const SizedBox(width: 4),
                _ActionBtn(icon: Icons.delete_outline_rounded, color: AppColors.error, tooltip: 'Șterge', onTap: onDelete),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Narrow mobile card ────────────────────────────────────────────────────────

class _NarrowCard extends StatelessWidget {
  const _NarrowCard({required this.child, required this.isAdmin, required this.onDelete});
  final ChildRow child;
  final bool isAdmin;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => context.go('/children/${child.id}'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            ChildAvatar(
              name: child.fullName,
              size: 36,
              workshopType: child.workshops.isNotEmpty
                  ? child.workshops.first.workshopType
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(child.fullName, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
            _ActiveBadge(isActive: child.isActive),
          ]),
          if (child.workshops.isNotEmpty) ...[const SizedBox(height: 8), _WorkshopBadgeRow(workshops: child.workshops)],
          if (child.lastAttDate != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.access_time_rounded, size: 13, color: theme.colorScheme.outline),
              const SizedBox(width: 4),
              Text(formatDate(child.lastAttDate!), style: theme.textTheme.bodySmall),
              const SizedBox(width: 6),
              _AttStatusText(status: child.lastAttStatus),
            ]),
          ],
          if (isAdmin) ...[
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              _ActionBtn(icon: Icons.visibility_outlined, color: AppColors.info, tooltip: 'Detalii', onTap: () => context.go('/children/${child.id}')),
              const SizedBox(width: 8),
              _ActionBtn(icon: Icons.edit_outlined, color: AppColors.warning, tooltip: 'Editează', onTap: () => context.go('/children/${child.id}/edit')),
              const SizedBox(width: 8),
              _ActionBtn(icon: Icons.delete_outline_rounded, color: AppColors.error, tooltip: 'Șterge', onTap: onDelete),
            ]),
          ],
        ]),
      ),
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _WorkshopBadgeRow extends StatelessWidget {
  const _WorkshopBadgeRow({required this.workshops});
  final List<ChildWorkshopSummary> workshops;

  @override
  Widget build(BuildContext context) {
    if (workshops.isEmpty) return const SizedBox.shrink();
    final extra = workshops.length - 1;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Flexible(child: _WorkshopBadge(workshop: workshops.first)),
      if (extra > 0) ...[
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
          child: Text('+$extra', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.outline)),
        ),
      ],
    ]);
  }
}

class _WorkshopBadge extends StatelessWidget {
  const _WorkshopBadge({required this.workshop});
  final ChildWorkshopSummary workshop;

  @override
  Widget build(BuildContext context) {
    final color = WorkshopTypeHelper.colorForType(workshop.workshopType);
    final raw = workshop.title.replaceFirst(RegExp(r'^[A-ZĂÂÎȘȚ]+ - '), '');
    final label = workshop.dayOfWeek.isEmpty ? raw : '${workshop.dayOfWeek} · $raw';
    return Container(
      constraints: const BoxConstraints(maxWidth: 160),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.25))),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge({required this.isActive});
  final bool? isActive;

  @override
  Widget build(BuildContext context) {
    final active = isActive == true;
    final color = active ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(active ? 'Activ' : 'Inactiv', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _AttStatusText extends StatelessWidget {
  const _AttStatusText({required this.status});
  final String? status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'present' => ('Prezent', AppColors.success),
      'absent' => ('Absent', AppColors.error),
      _ => ('—', Theme.of(context).colorScheme.outline),
    };
    return Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500));
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.icon, required this.color, required this.tooltip, required this.onTap});
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}
