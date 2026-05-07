import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/dashboard_stats.dart';
import '../domain/dashboard_workshop.dart';

class DashboardRepository {
  const DashboardRepository(this._client);

  final SupabaseClient _client;

  Future<DashboardStats?> getStats() async {
    // Run both queries in parallel to reduce latency.
    final results = await Future.wait<dynamic>([
      _client.from('dashboard_stats').select().maybeSingle(),
      _client
          .from('payment_cycles')
          .select('id')
          .inFilter('status', ['due', 'overdue']),
    ]);

    final statsData = results[0] as Map<String, dynamic>?;
    if (statsData == null) return null;

    final pendingCount = (results[1] as List).length;
    return DashboardStats.fromMap(statsData)
        .copyWith(pendingPayments: pendingCount);
  }

  Future<List<DashboardWorkshop>> getTodayWorkshops() async {
    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final data = await _client
        .from('dashboard_workshops')
        .select()
        .eq('workshop_date', dateStr)
        .order('start_time');
    return (data as List)
        .map((e) => DashboardWorkshop.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Calls the idempotent RPC that generates this week's workshop instances.
  /// [weekStart] must be the Monday of the target week (time is ignored).
  Future<void> generateWeeklyWorkshops(DateTime weekStart) async {
    final dateStr =
        '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
    await _client.rpc(
      'generate_recurring_workshops_for_week',
      params: {'p_week_start': dateStr},
    );
  }

  Future<List<DashboardWorkshop>> getAllScheduledWorkshops() async {
    final now = DateTime.now();
    // Monday of the current week
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    // Sunday of the current week
    final sunday = DateTime(monday.year, monday.month, monday.day + 6);

    String fmtDate(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final data = await _client
        .from('dashboard_workshops')
        .select()
        .gte('workshop_date', fmtDate(monday))
        .lte('workshop_date', fmtDate(sunday))
        .order('workshop_date')
        .order('start_time');
    return (data as List)
        .map((e) => DashboardWorkshop.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}
