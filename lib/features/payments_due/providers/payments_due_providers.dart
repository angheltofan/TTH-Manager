import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../data/payments_due_repository.dart';
import '../domain/payment_due_item.dart';

final paymentsDueRepositoryProvider = Provider<PaymentsDueRepository>((ref) {
  return PaymentsDueRepository(ref.watch(supabaseClientProvider));
});

final paymentsDueProvider = FutureProvider<List<PaymentDueItem>>((ref) {
  return ref.watch(paymentsDueRepositoryProvider).getPaymentsDue();
});
