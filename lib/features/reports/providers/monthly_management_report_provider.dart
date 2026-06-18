import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../data/monthly_management_report_repository.dart';

final monthlyManagementReportRepositoryProvider =
    Provider<MonthlyManagementReportRepository>((ref) {
  return MonthlyManagementReportRepository(ref.watch(supabaseClientProvider));
});
