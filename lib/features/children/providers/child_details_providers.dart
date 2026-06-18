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
//
// For paid children: behaviour unchanged — returns every unarchived
// attendance row whose `payment_cycle_id IS NULL`.
//
// For free children: the same fetch runs, but its result is then windowed
// client-side to the trailing "current block" (everything after the most
// recent 4th-present row). The DB trigger that auto-creates payment_cycles
// is blocked for free children, so without this windowing the row list
// would grow forever instead of resetting to 0/4. The dispatch reads the
// child's payment_type via `childByIdProvider`; while that future is
// loading we fall back to `'paid'` semantics — safe because the fallback
// is a strict superset of the free output.

final childCurrentStatusRowsProvider =
    FutureProvider.autoDispose.family<List<ChildCurrentStatusRow>, String>(
        (ref, childId) async {
  final child = await ref.watch(childByIdProvider(childId).future);
  final isFree = child?.isFreeParticipant ?? false;
  return ref
      .watch(childDetailsRepositoryProvider)
      .fetchChildCurrentStatusRows(childId, isFreeParticipant: isFree);
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
