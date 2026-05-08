/// A payment cycle record from the `payment_cycles` table.
class ChildPaymentCycle {
  const ChildPaymentCycle({
    required this.id,
    required this.childId,
    this.periodStart,
    this.periodEnd,
    this.sessionsCount,
    this.status,
    this.paidAt,
    this.confirmedBy,
    this.paymentMethod,
    this.notes,
    this.createdAt,
  });

  final String id;
  final String childId;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final int? sessionsCount;

  /// 'paid', 'due', 'overdue', 'cancelled'
  final String? status;
  final DateTime? paidAt;
  final String? confirmedBy;

  /// 'pos' or 'op', or null for legacy records.
  final String? paymentMethod;

  /// Optional free-text note — used as fallback to infer method for old records.
  final String? notes;
  final DateTime? createdAt;

  factory ChildPaymentCycle.fromMap(Map<String, dynamic> map) =>
      ChildPaymentCycle(
        id: (map['id'] as String?) ?? '',
        childId: (map['child_id'] as String?) ?? '',
        periodStart: map['period_start'] != null
            ? DateTime.tryParse(map['period_start'] as String)
            : null,
        periodEnd: map['period_end'] != null
            ? DateTime.tryParse(map['period_end'] as String)
            : null,
        sessionsCount: (map['sessions_count'] as num?)?.toInt(),
        status: map['status'] as String?,
        paidAt: map['paid_at'] != null
            ? DateTime.tryParse(map['paid_at'] as String)
            : null,
        confirmedBy: map['confirmed_by'] as String?,
        paymentMethod: map['payment_method'] as String?,
        notes: map['notes'] as String?,
        createdAt: map['created_at'] != null
            ? DateTime.tryParse(map['created_at'] as String)
            : null,
      );
}
