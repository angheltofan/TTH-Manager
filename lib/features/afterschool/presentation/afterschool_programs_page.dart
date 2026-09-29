import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../auth/providers/auth_providers.dart';
import '../domain/afterschool_program.dart';
import '../providers/afterschool_providers.dart';
import 'widgets/weekday_multi_selector.dart';

/// Afterschool overview — one row per program with a compact summary.
/// Staff can browse and open a program; only admin sees the "Adaugă
/// program" primary action and the per-row edit/archive controls.
class AfterschoolProgramsPage extends ConsumerWidget {
  const AfterschoolProgramsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final isAdmin = profile?.isAdmin ?? false;

    final programsAsync = ref.watch(afterschoolProgramsProvider);

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _Header(
                  isAdmin: isAdmin,
                  // Hide the global header CTA in the empty state on
                  // mobile so it doesn't visually compete with the
                  // "Creează program" CTA inside the empty card.
                  showAddAction: !programsAsync.maybeWhen(
                    data: (list) => list.isEmpty,
                    orElse: () => false,
                  ),
                ),
              ),
              programsAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: SizedBox(height: 120, child: AppLoading()),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: AppError(message: e.toString()),
                  ),
                ),
                data: (programs) {
                  if (programs.isEmpty) {
                    return SliverToBoxAdapter(
                      child: _EmptyState(isAdmin: isAdmin),
                    );
                  }
                  final horizontalPad = context.isMobile ? 16.0 : 24.0;
                  return SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                        horizontalPad, 8, horizontalPad, 24),
                    sliver: SliverList.separated(
                      itemCount: programs.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, i) => _ProgramRow(
                        program: programs[i],
                        isAdmin: isAdmin,
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.isAdmin, this.showAddAction = true});
  final bool isAdmin;

  /// Whether the "Adaugă program" primary action is rendered in the
  /// header. The Astăzi-programs page hides it on the empty state so
  /// the empty card's own CTA doesn't visually compete with a second
  /// header CTA — see the [_EmptyState] widget below.
  final bool showAddAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = context.isMobile;
    final horizontalPad = isMobile ? 16.0 : 24.0;

    final iconBadge = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.purple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.school_outlined,
          color: AppColors.purple, size: 22),
    );

    final titleColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Afterschool',
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          'Programe și copii înscriși',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    final action = (isAdmin && showAddAction)
        ? AppPrimaryButton(
            label: 'Adaugă program',
            icon: Icons.add_rounded,
            onPressed: () => context.go('/afterschool/programs/new'),
          )
        : null;

    if (isMobile) {
      return Padding(
        padding: EdgeInsets.fromLTRB(horizontalPad, 20, horizontalPad, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                iconBadge,
                const SizedBox(width: 12),
                Expanded(child: titleColumn),
              ],
            ),
            if (action != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: action,
              ),
            ],
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPad, 24, horizontalPad, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          iconBadge,
          const SizedBox(width: 14),
          Expanded(child: titleColumn),
          ?action,
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isAdmin});
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = context.isMobile;
    final outerPad = isMobile ? 16.0 : 24.0;
    final innerPad = isMobile ? 20.0 : 28.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(outerPad, 12, outerPad, 24),
      child: Container(
        padding: EdgeInsets.all(innerPad),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.35)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school_outlined,
                size: 40, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text('Nu există încă programe Afterschool',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              isAdmin
                  ? 'Creează primul program și apoi înscrie copiii.'
                  : 'Verifică din nou după ce un administrator adaugă un program.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
              textAlign: TextAlign.center,
            ),
            if (isAdmin) ...[
              const SizedBox(height: 16),
              AppPrimaryButton(
                label: 'Creează program',
                icon: Icons.add_rounded,
                onPressed: () => context.go('/afterschool/programs/new'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProgramRow extends ConsumerWidget {
  const _ProgramRow({required this.program, required this.isAdmin});
  final AfterschoolProgram program;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final countAsync =
        ref.watch(afterschoolActiveEnrollmentCountProvider(program.id));

    return InkWell(
      onTap: () => context.go('/afterschool/programs/${program.id}'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(program.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 10),
                      _StatusBadge(program: program),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatIsoWeekdaysShort(program.daysOfWeek)} · '
                    '${program.startTimeShort}–${program.endTimeShort}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            countAsync.when(
              data: (count) => _CapacityChip(
                  count: count, maxCapacity: program.maxCapacity),
              loading: () => const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              error: (_, _) => Text('—',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline)),
            ),
            const SizedBox(width: 16),
            _FeeLabel(program: program),
            if (isAdmin) ...[
              const SizedBox(width: 6),
              _RowMenu(program: program),
            ] else
              const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.program});
  final AfterschoolProgram program;

  @override
  Widget build(BuildContext context) {
    if (program.isArchived) {
      return _pill(context, 'Arhivat', AppColors.muted);
    }
    return _pill(context, 'Activ', AppColors.success);
  }

  Widget _pill(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _CapacityChip extends StatelessWidget {
  const _CapacityChip({required this.count, required this.maxCapacity});
  final int count;
  final int? maxCapacity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (maxCapacity == null) {
      return Text('$count copii',
          style: theme.textTheme.bodySmall);
    }
    final full = count >= maxCapacity!;
    return Text(
      '$count / $maxCapacity',
      style: theme.textTheme.bodySmall?.copyWith(
        color: full ? AppColors.warning : null,
        fontWeight: full ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }
}

class _FeeLabel extends StatelessWidget {
  const _FeeLabel({required this.program});
  final AfterschoolProgram program;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      '${_fmtFee(program.monthlyFee)} ${program.currency} / lună',
      style: theme.textTheme.bodySmall
          ?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

class _RowMenu extends ConsumerWidget {
  const _RowMenu({required this.program});
  final AfterschoolProgram program;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'Acțiuni',
      icon: const Icon(Icons.more_horiz),
      onSelected: (v) async {
        switch (v) {
          case 'open':
            context.go('/afterschool/programs/${program.id}');
            break;
          case 'edit':
            context.go('/afterschool/programs/${program.id}/edit');
            break;
          case 'archive':
            await _confirmArchive(context, ref, program);
            break;
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
            value: 'open',
            child: ListTile(
                leading: Icon(Icons.open_in_new_rounded),
                title: Text('Deschide'))),
        const PopupMenuItem(
            value: 'edit',
            child: ListTile(
                leading: Icon(Icons.edit_outlined),
                title: Text('Editează'))),
        if (!program.isArchived)
          const PopupMenuItem(
              value: 'archive',
              child: ListTile(
                  leading: Icon(Icons.archive_outlined),
                  title: Text('Arhivează'))),
      ],
    );
  }

  Future<void> _confirmArchive(
      BuildContext context, WidgetRef ref, AfterschoolProgram program) async {
    final profile = ref.read(currentProfileProvider).valueOrNull;
    final adminId = profile?.id;
    if (adminId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Arhivează programul?'),
        content: Text(
            'Programul "${program.name}" va deveni arhivat. Sesiunile și '
            'înscrierile deja existente rămân pentru istoric.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Renunță')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Arhivează'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(afterschoolProgramsRepositoryProvider).archive(
            isAdmin: true,
            id: program.id,
            adminId: adminId,
          );
      ref.invalidate(afterschoolProgramsProvider);
      ref.invalidate(afterschoolAllProgramsProvider);
      ref.invalidate(afterschoolProgramByIdProvider(program.id));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Program "${program.name}" arhivat')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Eroare la arhivare: $e')));
      }
    }
  }
}

String _fmtFee(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(2);
}
