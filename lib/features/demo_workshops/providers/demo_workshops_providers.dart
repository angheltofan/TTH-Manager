import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../workshops/domain/workshop_series.dart';
import '../data/demo_workshops_repository.dart';
import '../domain/demo_workshop.dart';

// ── Repository ────────────────────────────────────────────────────────────────

final demoWorkshopsRepositoryProvider =
    Provider<DemoWorkshopsRepository>((ref) {
  return DemoWorkshopsRepository(ref.watch(supabaseClientProvider));
});

// ── Today's demo workshops ────────────────────────────────────────────────────

final todayDemoWorkshopsProvider =
    FutureProvider<List<DemoWorkshop>>((ref) {
  return ref.watch(demoWorkshopsRepositoryProvider).getTodayDemos();
});

// ── Demo-uri page providers ───────────────────────────────────────────────────
//
// "Astăzi" / "Următoare" / "Istoric" views. Each returns the full set of
// matching demos (any status) so a marked / converted / cancelled demo
// doesn't vanish from the list once it leaves the `scheduled` bucket.

/// Family key for the per-day Demo-uri view. Keyed by (year, month, day)
/// so the current-day provider doesn't re-fetch when the user navigates
/// away and back (the DateTime instance would otherwise differ).
class DemosDayKey {
  const DemosDayKey({required this.year, required this.month, required this.day});
  factory DemosDayKey.fromDate(DateTime d) =>
      DemosDayKey(year: d.year, month: d.month, day: d.day);

  final int year;
  final int month;
  final int day;

  DateTime toDate() => DateTime(year, month, day);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DemosDayKey &&
          other.year == year &&
          other.month == month &&
          other.day == day);

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() =>
      'DemosDayKey(${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')})';
}

/// Every demo on [key]'s date, any status.
final demosForDayProvider =
    FutureProvider.family<List<DemoWorkshop>, DemosDayKey>((ref, key) {
  return ref
      .watch(demoWorkshopsRepositoryProvider)
      .getForDate(key.toDate());
});

/// Future demos (strictly after today), ascending.
final upcomingDemosProvider =
    FutureProvider<List<DemoWorkshop>>((ref) {
  return ref.watch(demoWorkshopsRepositoryProvider).getUpcoming();
});

/// Past demos (strictly before today), newest first.
final historyDemosProvider =
    FutureProvider<List<DemoWorkshop>>((ref) {
  return ref.watch(demoWorkshopsRepositoryProvider).getHistory();
});

// ── Single demo by id ─────────────────────────────────────────────────────────

final demoWorkshopByIdProvider =
    FutureProvider.autoDispose.family<DemoWorkshop?, String>((ref, id) {
  return ref.watch(demoWorkshopsRepositoryProvider).getById(id);
});

// ── Active series for demo dropdown (includes trainer names) ──────────────────

final activeSeriesForDemoProvider =
    FutureProvider<List<WorkshopSeries>>((ref) {
  return ref
      .watch(demoWorkshopsRepositoryProvider)
      .fetchActiveSeriesForDemo();
});
