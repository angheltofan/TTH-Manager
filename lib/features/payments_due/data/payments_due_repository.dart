import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/payment_due_item.dart';

class PaymentsDueRepository {
  const PaymentsDueRepository(this._client);

  final SupabaseClient _client;

  /// Loads all payment_cycles with status 'due' or 'overdue'.
  /// This is the single source of truth — do not infer from attendance count.
  Future<List<PaymentDueItem>> getPaymentsDue() async {
    final data = await _client
        .from('payment_cycles')
        .select(
          'id, child_id, status, period_start, period_end, sessions_count, '
          'children!child_id(first_name, last_name)',
        )
        .inFilter('status', ['due', 'overdue'])
        .order('period_start', ascending: false);

    return (data as List)
        .map((e) => PaymentDueItem.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}
