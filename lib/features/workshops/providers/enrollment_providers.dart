import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

// ── Global realtime for workshop_enrollments ─────────────────────────────

/// Watches [workshop_enrollments] for changes and invalidates series
/// providers so lists update on other devices.
/// Watched by [AppShell] while the user is logged in.
final enrollmentRealtimeProvider = Provider.autoDispose<void>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (kDebugMode) debugPrint('[RT] workshop_enrollments: subscribing');

  final channel = client
      .channel('global_workshop_enrollments')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'workshop_enrollments',
        callback: (payload) {
          if (kDebugMode) {
            debugPrint('[RT] workshop_enrollments → ${payload.eventType}');
          }
          ref.invalidate(activeWorkshopSeriesProvider);
          if (kDebugMode) {
            debugPrint('[RT] activeWorkshopSeriesProvider invalidated');
          }
        },
      )
      .subscribe();

  ref.onDispose(() {
    if (kDebugMode) debugPrint('[RT] workshop_enrollments: removing channel');
    client.removeChannel(channel);
  });
});
