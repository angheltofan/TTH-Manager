import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../data/afterschool_attendance_repository.dart';
import '../data/afterschool_enrollments_repository.dart';
import '../data/afterschool_payments_repository.dart';
import '../data/afterschool_programs_repository.dart';
import '../data/afterschool_sessions_repository.dart';

/// Phase 1 providers — repository singletons only. UI-facing state
/// (today's roster, month calendar, per-child summaries) is deferred
/// to Phase 2/3/4 so this file stays minimal and infrastructure-only.
/// No realtime channels, no autoDispose families here yet.

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
