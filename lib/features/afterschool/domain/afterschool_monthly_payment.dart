/// Monthly billing row from `afterschool_monthly_payments`.
///
/// One row per `(child, program, year, month)` — enforced by
/// `uq_afs_pay_child_program_ym`, so double-click confirm is safe.
///
/// `amount` is a SNAPSHOT captured at row creation; program fee
/// changes after materialization must not rewrite historical rows.
///
/// Status transitions handled by RPCs:
///   - `due` → `paid`     via `confirm_afterschool_payment`
///   - `due` → `cancelled` via admin operation (Phase 4)
/// A `paid` row is idempotent under repeat confirm calls.
class AfterschoolMonthlyPayment {
  const AfterschoolMonthlyPayment({
    required this.id,
    required this.childId,
    required this.programId,
    required this.year,
    required this.month,
    required this.amount,
    required this.currency,
    required this.status,
    this.paidAt,
    this.paymentMethod,
    this.confirmedBy,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String childId;
  final String programId;
  final int year;
  final int month;
  final double amount;
  final String currency;
  final MonthlyPaymentStatus status;
  final DateTime? paidAt;

  /// `'pos'` or `'op'` — matches the convention used across the
  /// workshop payment stack.
  final String? paymentMethod;
  final String? confirmedBy;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isDue => status == MonthlyPaymentStatus.due;
  bool get isPaid => status == MonthlyPaymentStatus.paid;
  bool get isCancelled => status == MonthlyPaymentStatus.cancelled;

  /// A due payment turns "overdue" client-side once the target month
  /// has fully elapsed. Stored status stays `due` — this is a purely
  /// derived flag for UI badges. Kept out of the DB per Phase 0 plan.
  bool isOverdueAsOf(DateTime today) {
    if (status != MonthlyPaymentStatus.due) return false;
    final lastDayOfMonth = DateTime(year, month + 1, 0);
    return today.isAfter(lastDayOfMonth);
  }

  factory AfterschoolMonthlyPayment.fromMap(Map<String, dynamic> map) {
    return AfterschoolMonthlyPayment(
      id: map['id'] as String,
      childId: map['child_id'] as String,
      programId: map['program_id'] as String,
      year: (map['year'] as num).toInt(),
      month: (map['month'] as num).toInt(),
      amount: (map['amount'] as num).toDouble(),
      currency: (map['currency'] as String?) ?? 'RON',
      status: MonthlyPaymentStatus.fromDb(map['status'] as String? ?? 'due'),
      paidAt: map['paid_at'] != null
          ? DateTime.parse(map['paid_at'] as String)
          : null,
      paymentMethod: map['payment_method'] as String?,
      confirmedBy: map['confirmed_by'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

enum MonthlyPaymentStatus {
  due,
  paid,
  cancelled;

  String toDb() => name;

  static MonthlyPaymentStatus fromDb(String raw) {
    switch (raw) {
      case 'paid':
        return MonthlyPaymentStatus.paid;
      case 'cancelled':
        return MonthlyPaymentStatus.cancelled;
      case 'due':
      default:
        return MonthlyPaymentStatus.due;
    }
  }
}
