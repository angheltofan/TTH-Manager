import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../data/enrollment_repository.dart';
import '../domain/series_enrolled_child.dart';
import '../domain/workshop_series.dart';

// ── Repository ────────────────────────────────────────────────────────────────

final enrollmentRepositoryProvider = Provider<EnrollmentRepository>((ref) {
  return EnrollmentRepository(ref.watch(supabaseClientProvider));
});

// ── Workshop Series ───────────────────────────────────────────────────────────

final activeWorkshopSeriesProvider =
    FutureProvider<List<WorkshopSeries>>((ref) {
  return ref
      .watch(enrollmentRepositoryProvider)
      .fetchActiveWorkshopSeries();
});

final workshopSeriesByIdProvider =
    FutureProvider.family<WorkshopSeries?, String>((ref, id) {
  return ref
      .watch(enrollmentRepositoryProvider)
      .fetchWorkshopSeriesById(id);
});

// ── Child → Series ────────────────────────────────────────────────────────────

final childWorkshopSeriesProvider =
    FutureProvider.family<List<WorkshopSeries>, String>((ref, childId) {
  return ref
      .watch(enrollmentRepositoryProvider)
      .fetchChildWorkshopSeries(childId);
});

/// Active workshop series the child is NOT yet enrolled in.
/// Used by [AddToWorkshopDialog].
final availableWorkshopSeriesForChildProvider =
    FutureProvider.family<List<WorkshopSeries>, String>((ref, childId) {
  return ref
      .watch(enrollmentRepositoryProvider)
      .fetchAvailableWorkshopSeriesForChild(childId);
});

// ── Series → Children ─────────────────────────────────────────────────────────

final seriesEnrolledChildrenProvider =
    FutureProvider.family<List<SeriesEnrolledChild>, String>(
        (ref, seriesId) {
  return ref
      .watch(enrollmentRepositoryProvider)
      .fetchWorkshopSeriesChildren(seriesId);
});

final availableChildrenForSeriesProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, seriesId) {
  return ref
      .watch(enrollmentRepositoryProvider)
      .fetchAvailableChildrenForSeries(seriesId);
});
