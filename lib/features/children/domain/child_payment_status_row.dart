/// A row from the `child_payment_status_rows` view – each attendance record
/// linked to its payment cycle context.
class ChildPaymentStatusRow {
  const ChildPaymentStatusRow({
    required this.childId,
    this.cycleId,
    this.workshopTitle,
    this.workshopDate,
    this.dayOfWeek,
    this.startTime,
    this.endTime,
    this.attendanceStatus,
    this.observation,
    this.periodStart,
    this.periodEnd,
    this.cycleStatus,
    this.paidAt,
    this.confirmedByName,
  });

  final String childId;
  final String? cycleId;
  final String? workshopTitle;
  final DateTime? workshopDate;
  final String? dayOfWeek;
  final String? startTime;
  final String? endTime;

  /// 'present', 'absent', 'motivated', or null.
  final String? attendanceStatus;
  final String? observation;
  final DateTime? periodStart;
  final DateTime? periodEnd;

  /// Payment cycle status: 'paid', 'due', 'overdue', 'cancelled'.
  final String? cycleStatus;
  final DateTime? paidAt;
  final String? confirmedByName;

  factory ChildPaymentStatusRow.fromMap(Map<String, dynamic> map) =>
      ChildPaymentStatusRow(
        childId: (map['child_id'] as String?) ?? '',
        // The view exposes the FK as `payment_cycle_id`; older builds /
        // alternative views may use `cycle_id`. Read both for safety.
        cycleId: (map['payment_cycle_id'] as String?) ??
            (map['cycle_id'] as String?),
        workshopTitle: map['workshop_title'] as String?,
        workshopDate: map['workshop_date'] != null
            ? DateTime.tryParse(map['workshop_date'] as String)
            : null,
        dayOfWeek: map['day_of_week'] as String?,
        startTime: map['start_time'] as String?,
        endTime: map['end_time'] as String?,
        attendanceStatus: map['attendance_status'] as String?,
        observation: map['observation'] as String?,
        periodStart: map['period_start'] != null
            ? DateTime.tryParse(map['period_start'] as String)
            : null,
        periodEnd: map['period_end'] != null
            ? DateTime.tryParse(map['period_end'] as String)
            : null,
        cycleStatus: map['cycle_status'] as String?,
        paidAt: map['paid_at'] != null
            ? DateTime.tryParse(map['paid_at'] as String)
            : null,
        confirmedByName: map['confirmed_by_name'] as String?,
      );
}
