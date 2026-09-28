import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/afterschool_monthly_payment.dart';

/// Data layer for `afterschool_monthly_payments`.
///
/// Materialization rules (enforced server-side by the RPCs, checked
/// client-side for a nicer error message):
///
///   • `ensureCurrentMonth` — safe to call on every page open. It
///     only materialises the CURRENT calendar month, and only when
///     the enrollment covers it. Never generates future or historic
///     rows as a side effect.
///
///   • `confirmPayment` — confirms an existing due row OR materialises
///     + confirms a new row when the target month is current or the
///     next calendar month (advance flow, Q2 cap). Refuses historical
///     unmaterialized months and any month beyond current + 1.
///
/// The client never rewrites `amount`, `paid_at`, `payment_method` or
/// `confirmed_by` directly — those come from the server through the
/// RPCs so audit metadata is authoritative.
class AfterschoolPaymentsRepository {
  const AfterschoolPaymentsRepository(this._client);

  final SupabaseClient _client;

  static const _selectCols = '''
id, child_id, program_id, year, month, amount, currency,
status, paid_at, payment_method, confirmed_by, notes,
created_at, updated_at
''';

  /// All monthly payments for a child (any program). Ordered newest
  /// first so the child profile shows the latest month at the top.
  Future<List<AfterschoolMonthlyPayment>> fetchForChild(
      String childId) async {
    final data = await _client
        .from('afterschool_monthly_payments')
        .select(_selectCols)
        .eq('child_id', childId)
        .order('year', ascending: false)
        .order('month', ascending: false);
    return (data as List)
        .map((e) =>
            AfterschoolMonthlyPayment.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// All payments for one child + program (all months, all statuses).
  Future<List<AfterschoolMonthlyPayment>> fetchForChildInProgram({
    required String childId,
    required String programId,
  }) async {
    final data = await _client
        .from('afterschool_monthly_payments')
        .select(_selectCols)
        .eq('child_id', childId)
        .eq('program_id', programId)
        .order('year', ascending: false)
        .order('month', ascending: false);
    return (data as List)
        .map((e) =>
            AfterschoolMonthlyPayment.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// All payments for one program in a specific month (the payments
  /// matrix cell view). Includes every child that already has a row —
  /// callers cross-reference with the enrollment list to discover
  /// missing rows and decide whether to call `ensureCurrentMonth`.
  Future<List<AfterschoolMonthlyPayment>> fetchForProgramMonth({
    required String programId,
    required int year,
    required int month,
  }) async {
    final data = await _client
        .from('afterschool_monthly_payments')
        .select(_selectCols)
        .eq('program_id', programId)
        .eq('year', year)
        .eq('month', month);
    return (data as List)
        .map((e) =>
            AfterschoolMonthlyPayment.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// All DUE (unpaid) payments for one program, past or current. Used
  /// by the "restanțe" dashboard tile and the payments tab.
  Future<List<AfterschoolMonthlyPayment>> fetchDueForProgram(
      String programId) async {
    final data = await _client
        .from('afterschool_monthly_payments')
        .select(_selectCols)
        .eq('program_id', programId)
        .eq('status', 'due')
        .order('year')
        .order('month');
    return (data as List)
        .map((e) =>
            AfterschoolMonthlyPayment.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Materialises the current month for (child, program) if not
  /// present and the enrollment covers it. Idempotent. Returns the
  /// row id (existing or newly created). Server refuses when there's
  /// no covering enrollment; those errors bubble up unchanged.
  Future<String> ensureCurrentMonth({
    required String childId,
    required String programId,
  }) async {
    final res = await _client
        .rpc('ensure_afterschool_current_month_payment', params: {
      'p_child_id': childId,
      'p_program_id': programId,
    });
    if (res is String) return res;
    throw StateError(
        'Unexpected response from ensure_afterschool_current_month_payment: $res');
  }

  /// Confirms a monthly payment. Behaviour split by the server RPC:
  ///   • existing due row → flipped to paid
  ///   • existing paid row → idempotent (no-op, returns same id)
  ///   • existing cancelled row → throws (server refuses)
  ///   • no row + target = current or next month → materialise + confirm
  ///   • no row + target < current → throws (historical requires
  ///     explicit admin action, deferred to Phase 4)
  ///   • no row + target > current + 1 → throws
  ///
  /// [paymentMethod] MUST be `'pos'` or `'op'` — matches the workshop
  /// convention (see `showPaymentMethodDialog`, which returns POS/OP
  /// upper-case; the caller lower-cases before passing here).
  Future<String> confirmPayment({
    required bool isStaff,
    required String childId,
    required String programId,
    required int year,
    required int month,
    required String paymentMethod,
    String? notes,
  }) async {
    if (!isStaff) {
      throw StateError(
          'Only admin or trainer may confirm an Afterschool payment');
    }
    if (paymentMethod != 'pos' && paymentMethod != 'op') {
      throw ArgumentError.value(paymentMethod, 'paymentMethod',
          'expected "pos" or "op"');
    }
    final res = await _client.rpc('confirm_afterschool_payment', params: {
      'p_child_id': childId,
      'p_program_id': programId,
      'p_year': year,
      'p_month': month,
      'p_payment_method': paymentMethod,
      'p_notes':
          notes == null || notes.trim().isEmpty ? null : notes.trim(),
    });
    if (res is String) return res;
    throw StateError(
        'Unexpected response from confirm_afterschool_payment: $res');
  }
}
