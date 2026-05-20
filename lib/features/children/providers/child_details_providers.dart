import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../data/child_details_repository.dart';
import '../domain/child_current_status.dart';
import '../domain/child_current_status_row.dart';
import '../domain/child_model.dart';
import '../domain/child_payment_cycle.dart';
import '../domain/child_payment_status_row.dart';

// ── Repository ────────────────────────────────────────────────────────────────

final childDetailsRepositoryProvider =
    Provider<ChildDetailsRepository>((ref) {
  return ChildDetailsRepository(ref.watch(supabaseClientProvider));
});

// ── Child by ID ───────────────────────────────────────────────────────────────

final childByIdProvider =
    FutureProvider.autoDispose.family<ChildModel?, String>((ref, childId) {
  return ref
      .watch(childDetailsRepositoryProvider)
      .fetchChildById(childId);
});


// ── Current cycle summary ─────────────────────────────────────────────────────

final childCurrentStatusProvider =
    FutureProvider.autoDispose.family<ChildCurrentStatus?, String>(
        (ref, childId) {
  return ref
      .watch(childDetailsRepositoryProvider)
      .fetchChildCurrentStatus(childId);
});

// ── Current cycle attendance rows ─────────────────────────────────────────────

final childCurrentStatusRowsProvider =
    FutureProvider.autoDispose.family<List<ChildCurrentStatusRow>, String>(
        (ref, childId) {
  return ref
      .watch(childDetailsRepositoryProvider)
      .fetchChildCurrentStatusRows(childId);
});

// ── Payment status rows ───────────────────────────────────────────────────────

final childPaymentStatusRowsProvider =
    FutureProvider.autoDispose.family<List<ChildPaymentStatusRow>, String>(
        (ref, childId) {
  return ref
      .watch(childDetailsRepositoryProvider)
      .fetchChildPaymentStatusRows(childId);
});

// ── Payment cycles ────────────────────────────────────────────────────────────

final childPaymentCyclesNewProvider =
    FutureProvider.autoDispose.family<List<ChildPaymentCycle>, String>(
        (ref, childId) {
  return ref
      .watch(childDetailsRepositoryProvider)
      .fetchPaymentCycles(childId);
});
