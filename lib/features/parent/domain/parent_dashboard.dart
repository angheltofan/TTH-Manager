// Domain models for the parent dashboard.
//
// All data is composed from PostgREST queries against tables for which
// the parent role has explicit P2 SELECT policies:
//   • child_parents, children, attendance, payment_cycles,
//     workshop_enrollments, scheduled_workshops, notifications.
//
// Notes:
//   • Trainer names are NOT included — parent role has no SELECT on
//     staff profiles by design.
//   • Workshop titles come from `scheduled_workshops.title`
//     (denormalised) so we don't need parent SELECT on workshop_series.

// ── Linked child summary on the dashboard card ──────────────────────────────

class ParentDashboardChild {
  const ParentDashboardChild({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.relationship,
    this.isPrimary = false,
    required this.activeWorkshopCount,
    required this.currentCyclePresent,
    this.currentCycleTarget = 4,
    this.paymentStatus,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String? relationship;
  final bool isPrimary;

  /// Number of currently active `workshop_enrollments` rows.
  final int activeWorkshopCount;

  /// Count of `attendance` rows for this child where status='present',
  /// payment_cycle_id IS NULL, is_archived=false. Represents progress
  /// toward the next closed cycle.
  final int currentCyclePresent;

  /// Sessions per closed cycle. 4 today; kept as a field for future
  /// flexibility.
  final int currentCycleTarget;

  /// Latest `payment_cycles.status` for this child, or null if no cycle
  /// has been created yet. Raw values: 'paid', 'paid_advance', 'due',
  /// 'overdue', 'cancelled'.
  final String? paymentStatus;

  String get fullName => '$firstName $lastName'.trim();
}

// ── Next scheduled workshop for a child ─────────────────────────────────────

class ParentNextWorkshop {
  const ParentNextWorkshop({
    required this.id,
    this.title,
    this.workshopType,
    this.workshopDate,
    this.dayOfWeek,
    this.startTime,
    this.endTime,
    this.isActive = true,
  });

  final String id;
  final String? title;
  final String? workshopType;
  final DateTime? workshopDate;
  final String? dayOfWeek;
  final String? startTime;
  final String? endTime;
  final bool isActive;

  factory ParentNextWorkshop.fromMap(Map<String, dynamic> map) {
    return ParentNextWorkshop(
      id: map['id'] as String,
      title: map['title'] as String?,
      workshopType: map['workshop_type'] as String?,
      workshopDate: map['workshop_date'] != null
          ? DateTime.tryParse(map['workshop_date'] as String)
          : null,
      dayOfWeek: map['day_of_week'] as String?,
      startTime: map['start_time'] as String?,
      endTime: map['end_time'] as String?,
      isActive: (map['is_active'] as bool?) ?? true,
    );
  }
}

// ── Recent activity ─────────────────────────────────────────────────────────

class ParentRecentAttendance {
  const ParentRecentAttendance({
    required this.id,
    this.status,
    this.workshopDate,
    this.workshopTitle,
  });

  final String id;
  final String? status; // 'present' | 'absent' | 'motivated'
  final DateTime? workshopDate;
  final String? workshopTitle;
}

class ParentRecentPayment {
  const ParentRecentPayment({
    required this.id,
    this.status,
    this.paidAt,
    this.periodStart,
    this.periodEnd,
  });

  final String id;
  final String? status; // 'paid' | 'paid_advance' | 'due' | 'overdue' | ...
  final DateTime? paidAt;
  final DateTime? periodStart;
  final DateTime? periodEnd;
}

class ParentRecentNotification {
  const ParentRecentNotification({
    required this.id,
    required this.title,
    this.body,
    this.createdAt,
    this.isRead = false,
  });

  final String id;
  final String title;
  final String? body;
  final DateTime? createdAt;
  final bool isRead;
}

class ParentRecentActivity {
  const ParentRecentActivity({
    this.lastAttendance,
    this.lastPayment,
    this.lastNotification,
  });

  final ParentRecentAttendance? lastAttendance;
  final ParentRecentPayment? lastPayment;
  final ParentRecentNotification? lastNotification;

  bool get isEmpty =>
      lastAttendance == null && lastPayment == null && lastNotification == null;
}
