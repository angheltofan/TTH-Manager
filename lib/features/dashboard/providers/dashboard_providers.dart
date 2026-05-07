import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../data/dashboard_repository.dart';
import '../domain/dashboard_stats.dart';
import '../domain/dashboard_workshop.dart';

// ── Monday of the current week ────────────────────────────────────────────────

DateTime _currentWeekMonday() {
  final now = DateTime.now();
  // weekday: 1=Monday … 7=Sunday
  return DateTime(now.year, now.month, now.day - (now.weekday - 1));
}

// ── Repository provider ───────────────────────────────────────────────────────

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(supabaseClientProvider));
});

// ── Weekly workshop generation ────────────────────────────────────────────────
//
// Calls the idempotent RPC before workshops are fetched.
// Returns null on success or an error message string on failure — never throws.
// Workshop providers depend on this provider so they always wait for the RPC.

final weeklyWorkshopGenerationProvider = FutureProvider<String?>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  try {
    await repo.generateWeeklyWorkshops(_currentWeekMonday());
    return null;
  } catch (e) {
    // Non-blocking: return error message so the page can show a SnackBar.
    return 'Generare automată eșuată: $e';
  }
});

// ── Stats ─────────────────────────────────────────────────────────────────────

final dashboardStatsProvider = FutureProvider<DashboardStats?>((ref) {
  return ref.watch(dashboardRepositoryProvider).getStats();
});

// ── Workshop providers (depend on generation, so RPC always runs first) ───────

final todayWorkshopsProvider = FutureProvider<List<DashboardWorkshop>>((ref) async {
  // Wait for RPC to finish (it never throws — errors are returned as a message).
  await ref.watch(weeklyWorkshopGenerationProvider.future);
  return ref.watch(dashboardRepositoryProvider).getTodayWorkshops();
});

final allScheduledWorkshopsProvider =
    FutureProvider<List<DashboardWorkshop>>((ref) async {
  await ref.watch(weeklyWorkshopGenerationProvider.future);
  return ref.watch(dashboardRepositoryProvider).getAllScheduledWorkshops();
});

