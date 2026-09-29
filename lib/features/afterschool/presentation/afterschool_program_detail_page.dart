import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../auth/providers/auth_providers.dart';
import '../../children/domain/child_row.dart';
import '../../children/providers/children_providers.dart';
import '../domain/afterschool_enrollment.dart';
import '../domain/afterschool_program.dart';
import '../providers/afterschool_providers.dart';
import 'widgets/edit_enrollment_dialog.dart';
import 'widgets/end_enrollment_dialog.dart';
import 'widgets/enroll_child_dialog.dart';
import 'widgets/weekday_multi_selector.dart';

/// One program's detail page. Header shows the program summary; body is
/// the list of currently-enrolled children. Deferred to Phase 3/4:
/// "Astăzi", "Calendar", "Plăți" tabs — the spec says not to add
/// placeholder empty tabs, so this page only exposes the "Copii
/// înscriși" section.
class AfterschoolProgramDetailPage extends ConsumerWidget {
  const AfterschoolProgramDetailPage({super.key, required this.programId});
  final String programId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final isAdmin = profile?.isAdmin ?? false;

    final programAsync =
        ref.watch(afterschoolProgramByIdProvider(programId));
    final enrollmentsAsync =
        ref.watch(afterschoolActiveEnrollmentsForProgramProvider(programId));
    final childrenAsync = ref.watch(allChildrenProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Program Afterschool'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/afterschool/programs'),
        ),
      ),
      body: programAsync.when(
        loading: () => const SizedBox.expand(child: AppLoading()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: AppError(message: e.toString()),
        ),
        data: (program) {
          if (program == null) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: AppError(message: 'Program inexistent.'),
            );
          }
          return LayoutBuilder(builder: (context, constraints) {
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _Header(program: program, isAdmin: isAdmin),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  sliver: SliverToBoxAdapter(
                    child: _EnrollmentsTitle(
                      program: program,
                      isAdmin: isAdmin,
                    ),
                  ),
                ),
                enrollmentsAsync.when(
                  loading: () => const SliverToBoxAdapter(
                    child: SizedBox(height: 100, child: AppLoading()),
                  ),
                  error: (e, _) => SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: AppError(message: e.toString()),
                    ),
                  ),
                  data: (enrollments) {
                    if (enrollments.isEmpty) {
                      return SliverToBoxAdapter(
                        child: _EmptyEnrollments(
                          program: program,
                          isAdmin: isAdmin,
                        ),
                      );
                    }
                    return childrenAsync.when(
                      loading: () => const SliverToBoxAdapter(
                          child: SizedBox(height: 80, child: AppLoading())),
                      error: (e, _) => SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: AppError(message: e.toString()),
                        ),
                      ),
                      data: (children) {
                        final byId = {for (final c in children) c.id: c};
                        // sort by child name
                        final sorted = [...enrollments]..sort((a, b) {
                            final na = byId[a.childId]?.fullName ?? a.childId;
                            final nb = byId[b.childId]?.fullName ?? b.childId;
                            return na.compareTo(nb);
                          });
                        return SliverPadding(
                          padding:
                              const EdgeInsets.fromLTRB(24, 4, 24, 24),
                          sliver: SliverList.separated(
                            itemCount: sorted.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) => _EnrollmentRow(
                              program: program,
                              enrollment: sorted[i],
                              child: byId[sorted[i].childId],
                              isAdmin: isAdmin,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            );
          });
        },
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.program, required this.isAdmin});
  final AfterschoolProgram program;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final countAsync =
        ref.watch(afterschoolActiveEnrollmentCountProvider(program.id));

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.school_outlined,
                    color: AppColors.purple, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(program.name,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
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
              if (isAdmin)
                TextButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Editează'),
                  onPressed: () =>
                      context.go('/afterschool/programs/${program.id}/edit'),
                ),
            ]),
            const SizedBox(height: 14),
            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                _stat(theme, Icons.groups_2_outlined, () {
                  return countAsync.when(
                    data: (count) => program.maxCapacity == null
                        ? '$count copii'
                        : '$count / ${program.maxCapacity}',
                    loading: () => '…',
                    error: (_, _) => '—',
                  );
                }()),
                _stat(theme, Icons.payments_outlined,
                    '${_fmtFee(program.monthlyFee)} ${program.currency} / lună'),
                if (program.description != null &&
                    program.description!.isNotEmpty)
                  _stat(theme, Icons.info_outline, program.description!),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(ThemeData theme, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.outline),
        const SizedBox(width: 6),
        Text(text, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _EnrollmentsTitle extends ConsumerWidget {
  const _EnrollmentsTitle({required this.program, required this.isAdmin});
  final AfterschoolProgram program;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final countAsync =
        ref.watch(afterschoolActiveEnrollmentCountProvider(program.id));
    return Row(
      children: [
        Expanded(
          child: Text('Copii înscriși',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ),
        if (isAdmin)
          countAsync.when(
            data: (count) {
              final full = program.maxCapacity != null &&
                  count >= program.maxCapacity!;
              return AppPrimaryButton(
                label: 'Înscrie copil',
                icon: Icons.person_add_alt_1,
                onPressed: () async {
                  await showEnrollChildDialog(
                    context: context,
                    ref: ref,
                    program: program,
                    currentActiveCount: count,
                  );
                  // dialog invalidates providers itself
                  if (full) {}
                },
              );
            },
            loading: () => const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
            error: (_, _) => const SizedBox.shrink(),
          ),
      ],
    );
  }
}

class _EmptyEnrollments extends StatelessWidget {
  const _EmptyEnrollments({
    required this.program,
    required this.isAdmin,
  });
  final AfterschoolProgram program;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            Icon(Icons.groups_2_outlined,
                size: 36, color: theme.colorScheme.outline),
            const SizedBox(height: 10),
            Text('Niciun copil înscris încă',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              isAdmin
                  ? 'Adaugă primul copil din butonul "Înscrie copil".'
                  : 'Contactează un administrator pentru înscrieri.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnrollmentRow extends ConsumerWidget {
  const _EnrollmentRow({
    required this.program,
    required this.enrollment,
    required this.child,
    required this.isAdmin,
  });
  final AfterschoolProgram program;
  final AfterschoolEnrollment enrollment;
  final ChildRow? child;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final daysLabel = enrollment.attendanceDays == null
        ? formatIsoWeekdaysShort(program.daysOfWeek)
        : formatIsoWeekdaysShort(enrollment.attendanceDays!);
    final arrival = enrollment.expectedArrivalTime;
    final customFee = enrollment.customMonthlyFee;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(child?.fullName ?? enrollment.childId,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  daysLabel +
                      (arrival == null
                          ? ''
                          : ' · Sosire ~${_shortTime(arrival)}'),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
                if (customFee != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Tarif personalizat: ${_fmtFee(customFee)} ${program.currency}/lună',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.info, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
          if (isAdmin) _rowMenu(context, ref),
        ],
      ),
    );
  }

  Widget _rowMenu(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'Acțiuni',
      icon: const Icon(Icons.more_horiz),
      onSelected: (v) async {
        switch (v) {
          case 'edit':
            await showEditEnrollmentDialog(
              context: context,
              ref: ref,
              program: program,
              enrollment: enrollment,
              childName: child?.fullName ?? enrollment.childId,
            );
            break;
          case 'end':
            await showEndEnrollmentDialog(
              context: context,
              ref: ref,
              program: program,
              enrollment: enrollment,
              childName: child?.fullName ?? enrollment.childId,
            );
            break;
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
            value: 'edit',
            child: ListTile(
                leading: Icon(Icons.edit_outlined),
                title: Text('Editează înscrierea'))),
        PopupMenuItem(
            value: 'end',
            child: ListTile(
                leading: Icon(Icons.event_busy_outlined),
                title: Text('Încheie înscrierea'))),
      ],
    );
  }
}

String _fmtFee(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(2);
}

String _shortTime(String hhmmss) =>
    hhmmss.length >= 5 ? hhmmss.substring(0, 5) : hhmmss;
