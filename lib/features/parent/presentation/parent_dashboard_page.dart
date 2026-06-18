import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/parent_dashboard_providers.dart';
import 'widgets/parent_activity_schedule_section.dart';
import 'widgets/parent_children_section.dart';
import 'widgets/parent_greeting.dart';
import 'widgets/parent_kpi_grid.dart';
import 'widgets/parent_quick_contact_card.dart';

/// Parent dashboard mounted at `/parent`. Renders inside the persistent
/// [ParentShell] — owns its content, scroll view and `RefreshIndicator`
/// but no scaffold of its own. Each section is a self-contained widget
/// under `widgets/` so additions stay localised.
class ParentDashboardPage extends ConsumerWidget {
  const ParentDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final user = ref.watch(currentUserProvider);
    final firstName =
        resolveParentGreetingName(profile?.firstName, user?.email);

    return RefreshIndicator(
      onRefresh: () async {
        // Invalidate every dashboard provider. Base + enrollments are
        // long-lived (non-autoDispose) — explicit invalidation forces
        // them to re-run on pull-to-refresh.
        ref.invalidate(parentLinkedChildrenProvider);
        ref.invalidate(parentNextWorkshopSummaryProvider);
        ref.invalidate(parentAttendanceRateSummaryProvider);
        ref.invalidate(parentWeeklyScheduleProvider);
        ref.invalidate(parentRecentActivityFeedProvider(3));
        await Future.wait([
          ref.read(parentLinkedChildrenProvider.future),
          ref.read(parentNextWorkshopSummaryProvider.future),
          ref.read(parentAttendanceRateSummaryProvider.future),
          ref.read(parentWeeklyScheduleProvider.future),
          ref.read(parentRecentActivityFeedProvider(3).future),
        ]);
      },
      child: _DashboardBody(firstName: firstName),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.firstName});
  final String firstName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childrenAsync = ref.watch(parentLinkedChildrenProvider);
    final nextWorkshopAsync = ref.watch(parentNextWorkshopSummaryProvider);
    final attendanceRateAsync =
        ref.watch(parentAttendanceRateSummaryProvider);
    final paymentSummaryAsync = ref.watch(parentPaymentSummaryProvider);
    final scheduleAsync = ref.watch(parentWeeklyScheduleProvider);
    final recentAsync = ref.watch(parentRecentActivityFeedProvider(3));

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        return ListView(
          padding: const EdgeInsets.all(24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            ParentGreeting(firstName: firstName),
            const SizedBox(height: 16),
            childrenAsync.when(
              loading: () => const SizedBox(height: 96, child: AppLoading()),
              error: (e, _) => AppError(message: e.toString()),
              data: (children) => ParentKpiGrid(
                children: children,
                nextWorkshopAsync: nextWorkshopAsync,
                attendanceRateAsync: attendanceRateAsync,
                paymentSummaryAsync: paymentSummaryAsync,
              ),
            ),
            const SizedBox(height: 24),
            childrenAsync.when(
              loading: () =>
                  const SizedBox(height: 160, child: AppLoading()),
              error: (e, _) {
                if (kDebugMode) {
                  debugPrint('[Parent/Dashboard] children load failed: $e');
                }
                return AppError(message: e.toString());
              },
              data: (children) => ParentChildrenSection(
                children: children,
                isWide: isWide,
              ),
            ),
            const SizedBox(height: 24),
            childrenAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (children) => ParentActivityAndScheduleSection(
                recentAsync: recentAsync,
                scheduleAsync: scheduleAsync,
                showChildLabels: children.length > 1,
                isWide: isWide,
              ),
            ),
            const SizedBox(height: 24),
            const ParentQuickContactCard(title: 'Ai nevoie de ajutor?'),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}
