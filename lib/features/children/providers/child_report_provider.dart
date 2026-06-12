import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../data/child_report_repository.dart';
import '../domain/child_activity_report.dart';

final childReportRepositoryProvider = Provider<ChildReportRepository>((ref) {
  return ChildReportRepository(ref.watch(supabaseClientProvider));
});

/// On-demand fetch for the Child Activity Report PDF, keyed by child id.
/// `autoDispose` — the report is built once per button tap; the cached value
/// is discarded as soon as the request widget unmounts.
final childActivityReportProvider = FutureProvider.autoDispose
    .family<ChildActivityReportData, String>((ref, childId) {
  return ref.watch(childReportRepositoryProvider).fetchChildActivityReport(childId);
});
