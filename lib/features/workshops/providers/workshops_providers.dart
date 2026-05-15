import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../data/workshops_repository.dart';
import '../domain/scheduled_workshop.dart';
import '../domain/workshop_detail_row.dart';

// ── Repository ────────────────────────────────────────────────────────────────

final workshopsRepositoryProvider = Provider<WorkshopsRepository>((ref) {
  return WorkshopsRepository(ref.watch(supabaseClientProvider));
});

// ── Providers used by WorkshopDetailsPage ─────────────────────────────────────

final workshopDetailsProvider =
    FutureProvider.family<List<WorkshopDetailRow>, String>(
  (ref, workshopId) {
    return ref.watch(workshopsRepositoryProvider).getDetails(workshopId);
  },
);

// ── Provider used by ChildEnrollmentSection ───────────────────────────────────

final workshopsListProvider = FutureProvider<List<ScheduledWorkshop>>((ref) {
  return ref.watch(workshopsRepositoryProvider).getAll();
});

// ── Single workshop by ID (used by WorkshopFormPage in edit mode) ─────────────

final workshopByIdProvider =
    FutureProvider.family<ScheduledWorkshop?, String>((ref, id) {
  return ref.watch(workshopsRepositoryProvider).getById(id);
});

// ── Trainer dropdown options (profiles with role trainer or admin) ─────────────

class TrainerOption {
  const TrainerOption({required this.id, required this.displayName});
  final String id;
  final String displayName;
}

final trainersForDropdownProvider =
    FutureProvider<List<TrainerOption>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from('profiles')
      .select('id, first_name, last_name')
      .inFilter('role', ['trainer', 'admin'])
      .order('first_name');
  return (data as List)
      .map((e) => TrainerOption(
            id: e['id'] as String,
            displayName: '${e['first_name']} ${e['last_name']}',
          ))
      .toList();
});

// ── Global realtime for scheduled_workshops ───────────────────────────────────

/// Watches [scheduled_workshops] for INSERT/UPDATE/DELETE events and
/// invalidates list providers so the UI refreshes on any device.
/// Watched by [AppShell] while the user is logged in.
final workshopsRealtimeProvider = Provider.autoDispose<void>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (kDebugMode) debugPrint('[RT] scheduled_workshops: subscribing');

  final channel = client
      .channel('global_scheduled_workshops')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'scheduled_workshops',
        callback: (payload) {
          if (kDebugMode) {
            debugPrint('[RT] scheduled_workshops → ${payload.eventType}');
          }
          ref.invalidate(allScheduledWorkshopsProvider);
          ref.invalidate(todayWorkshopsProvider);
          ref.invalidate(workshopsListProvider);
          if (kDebugMode) {
            debugPrint('[RT] workshop list providers invalidated');
          }
        },
      )
      .subscribe();

  ref.onDispose(() {
    if (kDebugMode) debugPrint('[RT] scheduled_workshops: removing channel');
    client.removeChannel(channel);
  });
});
