import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/section_card.dart';
import '../../auth/providers/auth_providers.dart';
import '../../demo_workshops/providers/demo_workshops_providers.dart';
import '../../notifications/providers/notifications_providers.dart';
import '../../team_chat/presentation/widgets/chat_fab.dart';
import '../providers/dashboard_providers.dart';
import 'widgets/all_workshops_card.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/dashboard_stat_grid.dart';
import 'widgets/workshops_today_section.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  @override
  void initState() {
    super.initState();
    // Trigger daily birthday-notification generation exactly once per session.
    // The FutureProvider is not auto-disposed, so subsequent visits here
    // will find it already resolved and will not call the RPC again.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(dailyNotificationsGenerationProvider.future).ignore();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show a non-blocking SnackBar if weekly workshop generation failed.
    // The workshop providers still load because the generation provider
    // never throws — it returns an error message string instead.
    ref.listen<AsyncValue<String?>>(
      weeklyWorkshopGenerationProvider,
      (_, next) {
        final errorMsg = next.valueOrNull;
        if (errorMsg != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );

    final statsAsync = ref.watch(dashboardStatsProvider);
    final workshopsAsync = ref.watch(todayWorkshopsProvider);
    final demosAsync = ref.watch(todayDemoWorkshopsProvider);
    final currentUser = ref.watch(currentUserProvider);
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final isAdmin = profile?.isAdmin ?? false;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton:
          (profile?.isAdmin == true || profile?.isTrainer == true)
              ? const ChatFab()
              : null,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const DashboardHeader(),
              const SizedBox(height: 16),

              statsAsync.when(
                data: (stats) => DashboardStatGrid(stats: stats),
                loading: () =>
                    const SizedBox(height: 96, child: AppLoading()),
                error: (e, _) => AppError(message: e.toString()),
              ),

              const SizedBox(height: 24),

              workshopsAsync.when(
                loading: () =>
                    const SizedBox(height: 160, child: AppLoading()),
                error: (e, _) => AppError(message: e.toString()),
                data: (workshops) {
                  final demos = demosAsync.valueOrNull ?? [];
                  final totalCount = workshops.length + demos.length;

                  final trailing = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (totalCount > 0)
                        WorkshopsCountBadge(count: totalCount),
                      if (isAdmin) ...[
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          onPressed: () => context.go('/demo-workshops/new'),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Demo'),
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ],
                  );

                  if (isWide) {
                    return SizedBox(
                      height: 430,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: SectionCard(
                              title: 'Ateliere programate azi',
                              trailing: trailing,
                              padding:
                                  const EdgeInsets.fromLTRB(16, 10, 16, 14),
                              expanded: true,
                              child: WorkshopsTodayList(
                                workshops: workshops,
                                demos: demos,
                                currentUserId: currentUser?.id,
                                scrollable: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          const Expanded(child: AllWorkshopsCard()),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: [
                      SectionCard(
                        title: 'Ateliere programate azi',
                        trailing: trailing,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        child: WorkshopsTodayList(
                          workshops: workshops,
                          demos: demos,
                          currentUserId: currentUser?.id,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const SizedBox(height: 400, child: AllWorkshopsCard()),
                    ],
                  );
                },
              ),

              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }
}


