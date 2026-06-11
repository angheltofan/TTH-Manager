import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../data/parent_dashboard_repository.dart';
import '../domain/parent_dashboard.dart';
import 'parent_base_provider.dart';

// ── Repository ───────────────────────────────────────────────────────────────

final parentDashboardRepositoryProvider =
    Provider<ParentDashboardRepository>((ref) {
  return ParentDashboardRepository(ref.watch(supabaseClientProvider));
});

// ── Per-child summaries (derived from base + enrollments) ────────────────────

/// All linked children with the per-card summary fields. Reads the
/// base + enrollments providers (single `child_parents` + single
/// `workshop_enrollments` query for the whole dashboard) and fans out
/// per-child summary calls in parallel. Each call uses pre-loaded
/// series IDs, so `buildSummaryForChild` runs 4 queries (attendance
/// count, payment cycle, workshop snapshot, next session) in a single
/// `Future.wait` — no per-child `workshop_enrollments` query anymore.
final parentLinkedChildrenProvider =
    FutureProvider.autoDispose<List<ParentDashboardChild>>((ref) async {
  final base = await ref.watch(parentLinkedChildrenBaseProvider.future);
  final enrollments = await ref.watch(parentEnrollmentsProvider.future);
  if (base.isEmpty) return const [];

  final repo = ref.watch(parentDashboardRepositoryProvider);
  final summaries = await Future.wait(
    base.basics.map(
      (basic) => repo.buildSummaryForChild(
        basic,
        enrollments.seriesByChild[basic.id] ?? const <String>[],
      ),
    ),
  );
  return summaries;
});

// ── Next-workshop KPI ────────────────────────────────────────────────────────

final parentNextWorkshopSummaryProvider =
    FutureProvider.autoDispose<ParentNextWorkshopSummary?>((ref) async {
  final base = await ref.watch(parentLinkedChildrenBaseProvider.future);
  final enrollments = await ref.watch(parentEnrollmentsProvider.future);
  if (base.isEmpty || enrollments.isEmpty) return null;
  return ref
      .watch(parentDashboardRepositoryProvider)
      .getNextWorkshopSummary(base, enrollments);
});

// ── Attendance-rate KPI ──────────────────────────────────────────────────────

final parentAttendanceRateSummaryProvider =
    FutureProvider.autoDispose<ParentAttendanceRateSummary>((ref) async {
  final base = await ref.watch(parentLinkedChildrenBaseProvider.future);
  if (base.isEmpty) return const ParentAttendanceRateSummary.empty();
  return ref
      .watch(parentDashboardRepositoryProvider)
      .getAttendanceRateSummaryForIds(base.childIds);
});

// ── Payment KPI (sync derivation, no DB call) ────────────────────────────────

/// Parent-level payment summary derived from
/// `parentLinkedChildrenProvider` (no extra DB query — each child
/// already carries its latest cycle's `paymentStatus`). Priority is
/// `overdue > due > ok`.
final parentPaymentSummaryProvider =
    Provider.autoDispose<AsyncValue<ParentPaymentSummary>>((ref) {
  return ref.watch(parentLinkedChildrenProvider).whenData(
    (children) {
      final overdue = <ParentDashboardChild>[];
      final due = <ParentDashboardChild>[];
      for (final c in children) {
        if (c.paymentStatus == 'overdue') {
          overdue.add(c);
        } else if (c.paymentStatus == 'due') {
          due.add(c);
        }
      }
      if (overdue.isNotEmpty) {
        return ParentPaymentSummary(
          status: ParentPaymentSummaryStatus.overdue,
          overdueCount: overdue.length,
          dueCount: due.length,
          affectedChildFirstNames: overdue
              .map((c) => c.firstName.trim())
              .where((s) => s.isNotEmpty)
              .toList(),
        );
      }
      if (due.isNotEmpty) {
        return ParentPaymentSummary(
          status: ParentPaymentSummaryStatus.due,
          overdueCount: 0,
          dueCount: due.length,
          affectedChildFirstNames: due
              .map((c) => c.firstName.trim())
              .where((s) => s.isNotEmpty)
              .toList(),
        );
      }
      return const ParentPaymentSummary.ok();
    },
  );
});

// ── Recent activity feed ─────────────────────────────────────────────────────

final parentRecentActivityFeedProvider = FutureProvider.autoDispose
    .family<List<ParentRecentActivityItem>, int>((ref, limit) async {
  final base = await ref.watch(parentLinkedChildrenBaseProvider.future);
  if (base.isEmpty) return const [];
  return ref
      .watch(parentDashboardRepositoryProvider)
      .getRecentActivityForIds(base.childIds, limit: limit);
});

// ── Weekly schedule ──────────────────────────────────────────────────────────

final parentWeeklyScheduleProvider =
    FutureProvider.autoDispose<List<ParentWeeklySession>>((ref) async {
  final base = await ref.watch(parentLinkedChildrenBaseProvider.future);
  final enrollments = await ref.watch(parentEnrollmentsProvider.future);
  if (base.isEmpty || enrollments.isEmpty) return const [];

  // Monday-to-Sunday window for the current local week.
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final weekStart = today.subtract(Duration(days: today.weekday - 1));
  final weekEnd = weekStart.add(const Duration(days: 6));

  return ref
      .watch(parentDashboardRepositoryProvider)
      .getWeeklyScheduleForBase(
        base,
        enrollments,
        weekStart: weekStart,
        weekEnd: weekEnd,
      );
});
