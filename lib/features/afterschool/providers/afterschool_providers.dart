import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../data/afterschool_attendance_repository.dart';
import '../data/afterschool_enrollments_repository.dart';
import '../data/afterschool_payments_repository.dart';
import '../data/afterschool_programs_repository.dart';
import '../data/afterschool_sessions_repository.dart';
import '../domain/afterschool_enrollment.dart';
import '../domain/afterschool_program.dart';

/// ── Repository singletons ────────────────────────────────────────────

final afterschoolProgramsRepositoryProvider =
    Provider<AfterschoolProgramsRepository>((ref) {
  return AfterschoolProgramsRepository(ref.watch(supabaseClientProvider));
});

final afterschoolEnrollmentsRepositoryProvider =
    Provider<AfterschoolEnrollmentsRepository>((ref) {
  return AfterschoolEnrollmentsRepository(
      ref.watch(supabaseClientProvider));
});

final afterschoolSessionsRepositoryProvider =
    Provider<AfterschoolSessionsRepository>((ref) {
  return AfterschoolSessionsRepository(ref.watch(supabaseClientProvider));
});

final afterschoolAttendanceRepositoryProvider =
    Provider<AfterschoolAttendanceRepository>((ref) {
  return AfterschoolAttendanceRepository(
      ref.watch(supabaseClientProvider));
});

final afterschoolPaymentsRepositoryProvider =
    Provider<AfterschoolPaymentsRepository>((ref) {
  return AfterschoolPaymentsRepository(ref.watch(supabaseClientProvider));
});

/// ── UI-facing providers (Phase 2) ────────────────────────────────────
///
/// Convention matches [workshops_providers.dart]: plain [FutureProvider]
/// for the list, [FutureProvider.family] for detail-by-id. Mutations in
/// forms invalidate the list + the specific by-id entry.

/// All Afterschool programs, active first (archived hidden by default).
/// Set `includeArchived: true` via `afterschoolAllProgramsProvider` when
/// the UI needs to show archived rows too (Phase 2 keeps them hidden).
final afterschoolProgramsProvider =
    FutureProvider<List<AfterschoolProgram>>((ref) async {
  final repo = ref.watch(afterschoolProgramsRepositoryProvider);
  return repo.fetchAll(activeOnly: true);
});

/// Same as [afterschoolProgramsProvider] but includes archived rows.
/// Used only by the "arhivate" toggle if we add one later; safe to keep
/// wired up now so the toggle doesn't require a code change.
final afterschoolAllProgramsProvider =
    FutureProvider<List<AfterschoolProgram>>((ref) async {
  final repo = ref.watch(afterschoolProgramsRepositoryProvider);
  return repo.fetchAll(activeOnly: false);
});

/// One program by id. Used by the detail page and the edit form.
final afterschoolProgramByIdProvider =
    FutureProvider.family<AfterschoolProgram?, String>((ref, id) async {
  final repo = ref.watch(afterschoolProgramsRepositoryProvider);
  return repo.fetchById(id);
});

/// Currently-active enrollments for one program (no `enrolled_until`,
/// `is_active = true`). This is what the detail page shows as the
/// "Copii înscriși" list and what the program form uses to compute the
/// impact preview of a `days_of_week` narrow.
final afterschoolActiveEnrollmentsForProgramProvider =
    FutureProvider.family<List<AfterschoolEnrollment>, String>(
  (ref, programId) async {
    final repo = ref.watch(afterschoolEnrollmentsRepositoryProvider);
    return repo.fetchActiveForProgram(programId);
  },
);

/// Active-enrollment count for one program. Cheap projection used by the
/// overview row ("N / max") and by the enrollment dialog to decide
/// whether to show the capacity warning. Backed by the id-only select
/// helper in the repo — the whole list is not fetched here.
final afterschoolActiveEnrollmentCountProvider =
    FutureProvider.family<int, String>((ref, programId) async {
  final repo = ref.watch(afterschoolEnrollmentsRepositoryProvider);
  return repo.countActiveForProgram(programId);
});
