import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/afterschool_providers.dart';
import 'widgets/afterschool_day_navigator.dart';
import 'widgets/afterschool_program_today_card.dart';

/// Daily operations landing. Header + day navigator, then one card per
/// applicable program for the selected date. Empty state when nothing
/// runs that day. Staff (admin + trainer) reach this page; parents
/// are blocked at the router level.
class AfterschoolTodayPage extends ConsumerStatefulWidget {
  const AfterschoolTodayPage({super.key});

  @override
  ConsumerState<AfterschoolTodayPage> createState() =>
      _AfterschoolTodayPageState();
}

class _AfterschoolTodayPageState
    extends ConsumerState<AfterschoolTodayPage> {
  DateTime _date = _today();

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final isAdmin = profile?.isAdmin ?? false;

    final applicable = ref.watch(
        afterschoolApplicableProgramsForDateProvider(_date));

    return Scaffold(
      body: LayoutBuilder(builder: (context, constraints) {
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _Header(isAdmin: isAdmin),
            ),
            SliverToBoxAdapter(
              child: AfterschoolDayNavigator(
                date: _date,
                onDateChanged: (d) => setState(() => _date = d),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            applicable.when(
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
                    child: _EmptyDay(date: _date, theme: theme),
                  );
                }
                return SliverPadding(
                  padding:
                      const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  sliver: SliverList.separated(
                    itemCount: programs.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, i) =>
                        AfterschoolProgramTodayCard(
                            program: programs[i], date: _date),
                  ),
                );
              },
            ),
          ],
        );
      }),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.isAdmin});
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 20, 12),
      child: Row(
        children: [
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
                Text('Afterschool',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('Astăzi',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline)),
              ],
            ),
          ),
          if (isAdmin)
            TextButton.icon(
              icon: const Icon(Icons.list_alt_outlined, size: 16),
              label: const Text('Programe'),
              onPressed: () => context.go('/afterschool/programs'),
            ),
        ],
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.date, required this.theme});
  final DateTime date;
  final ThemeData theme;

  static const _weekdaysRo = [
    'luni', 'marți', 'miercuri', 'joi', 'vineri', 'sâmbătă', 'duminică'
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.35)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy_outlined,
                size: 40, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text('Nicio activitate Afterschool',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Niciun program nu funcționează ${_weekdaysRo[date.weekday - 1]} '
              'sau nu are perioada activă care să includă această zi.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
