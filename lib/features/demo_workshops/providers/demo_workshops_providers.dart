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

// ── Scoped invalidation helpers ──────────────────────────────────────────────
//
// A single demo lives in exactly one of the three Demo-uri tabs,
// determined by `demo_date` vs today. Status changes, convert and
// per-day attendance updates do not move it between tabs. These
// helpers invalidate only the tab the demo actually lives in,
// instead of the previous "invalidate all four" pattern that fired
// four Supabase SELECTs per mutation (one for each tab/dashboard
// provider).
//
// Realtime still fans out broadly for cross-device safety — this is
// about the initiating client's local round-trip cost.

/// Returns the bucket a demo on [date] belongs to, relative to today.
enum DemoBucket { today, upcoming, history }

DemoBucket demoBucketFor(DateTime date, [DateTime? todayOverride]) {
  final n = todayOverride ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(date.year, date.month, date.day);
  if (day.isAfter(today)) return DemoBucket.upcoming;
  if (day.isAtSameMomentAs(today)) return DemoBucket.today;
  return DemoBucket.history;
}

/// Invalidate the single provider that backs the Demo-uri tab the
/// demo on [date] is currently rendered in — plus
/// [todayDemoWorkshopsProvider] when the demo is today (for the
/// Dashboard "Ateliere azi" section).
void invalidateDemoBucketForDate(WidgetRef ref, DateTime date) {
  switch (demoBucketFor(date)) {
    case DemoBucket.today:
      ref.invalidate(demosForDayProvider(DemosDayKey.fromDate(date)));
      ref.invalidate(todayDemoWorkshopsProvider);
    case DemoBucket.upcoming:
      ref.invalidate(upcomingDemosProvider);
    case DemoBucket.history:
      ref.invalidate(historyDemosProvider);
  }
}

/// Ref-based variant used from inside Riverpod providers (notably the
/// `rt:demo_workshops` realtime callback). Identical semantics to
/// [invalidateDemoBucketForDate]; takes a plain `Ref` because the
/// realtime callback has no `WidgetRef`.
void invalidateDemoBucketForDateFromRef(Ref ref, DateTime date) {
  switch (demoBucketFor(date)) {
    case DemoBucket.today:
      ref.invalidate(demosForDayProvider(DemosDayKey.fromDate(date)));
      ref.invalidate(todayDemoWorkshopsProvider);
    case DemoBucket.upcoming:
      ref.invalidate(upcomingDemosProvider);
    case DemoBucket.history:
      ref.invalidate(historyDemosProvider);
  }
}
