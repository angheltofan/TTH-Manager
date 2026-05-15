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

// ── Single demo by id ─────────────────────────────────────────────────────────

final demoWorkshopByIdProvider =
    FutureProvider.family<DemoWorkshop?, String>((ref, id) {
  return ref.watch(demoWorkshopsRepositoryProvider).getById(id);
});

// ── Active series for demo dropdown (includes trainer names) ──────────────────

final activeSeriesForDemoProvider =
    FutureProvider<List<WorkshopSeries>>((ref) {
  return ref
      .watch(demoWorkshopsRepositoryProvider)
      .fetchActiveSeriesForDemo();
});
