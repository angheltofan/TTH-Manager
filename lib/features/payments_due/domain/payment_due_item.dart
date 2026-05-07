/// One due/overdue payment cycle with the child's name.
/// Queried from the `payment_cycles` table — the single source of truth.
class PaymentDueItem {
  const PaymentDueItem({
    required this.cycleId,
    required this.childId,
    required this.childFirstName,
    this.childLastName,
    this.periodStart,
    this.periodEnd,
    this.sessionsCount,
    required this.status,
  });

  final String cycleId;
  final String childId;
  final String childFirstName;
  final String? childLastName;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final int? sessionsCount;

  /// 'due' or 'overdue'
  final String status;

  String get fullName =>
      [childFirstName, childLastName]
          .where((s) => s != null && s.isNotEmpty)
          .join(' ');

  factory PaymentDueItem.fromMap(Map<String, dynamic> map) {
    final child = map['children'] as Map<String, dynamic>?;
    return PaymentDueItem(
      cycleId: map['id'] as String,
      childId: map['child_id'] as String,
      childFirstName: child?['first_name'] as String? ?? '—',
      childLastName: child?['last_name'] as String?,
      periodStart: map['period_start'] != null
          ? DateTime.tryParse(map['period_start'] as String)
          : null,
      periodEnd: map['period_end'] != null
          ? DateTime.tryParse(map['period_end'] as String)
          : null,
      sessionsCount: (map['sessions_count'] as num?)?.toInt(),
      status: map['status'] as String,
    );
  }
}

