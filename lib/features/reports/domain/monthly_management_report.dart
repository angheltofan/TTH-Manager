// Domain bundle for the monthly management PDF report. All fields are
// pre-resolved display values — no UUIDs, no raw table names, no raw
// nulls. The PDF service consumes this directly; the repository is
// the single integration point with the database.

class MonthlyManagementReportData {
  const MonthlyManagementReportData({
    required this.year,
    required this.month,
    required this.generatedAt,
    required this.executiveSummary,
    required this.children,
    required this.workshops,
    required this.attendance,
    required this.payments,
    required this.trainers,
    required this.parentPortal,
    required this.alerts,
    required this.recommendations,
  });

  final int year;
  final int month;
  final DateTime generatedAt;
  final ReportExecutiveSummary executiveSummary;
  final ReportChildrenStatus children;
  final ReportWorkshopsStatus workshops;
  final ReportAttendanceStatus attendance;
  final ReportPaymentsStatus payments;
  final ReportTrainersStatus trainers;
  final ReportParentPortalStatus parentPortal;

  /// Rule-based managerial alerts surfaced from the data (e.g. "5 copii
  /// fără părinte asociat"). Each entry is a fully-formed Romanian
  /// sentence ready to render as a bullet.
  final List<String> alerts;

  /// Rule-based recommendations derived from [alerts] and key metrics.
  final List<String> recommendations;
}

class ReportExecutiveSummary {
  const ReportExecutiveSummary({
    required this.activeChildren,
    required this.newChildren,
    required this.sessionsHeld,
    required this.attendanceRate,
    required this.paidCycles,
    required this.unpaidCycles,
    required this.demoCount,
  });

  final int activeChildren;
  final int newChildren;
  final int sessionsHeld;

  /// 0–100 (rounded percentage). Null when no attendance was marked.
  final int? attendanceRate;

  final int paidCycles;

  /// `due` + `overdue` count.
  final int unpaidCycles;
  final int demoCount;
}

class ReportChildrenStatus {
  const ReportChildrenStatus({
    required this.totalActive,
    required this.newThisMonth,
    required this.totalInactive,
    required this.withoutActiveWorkshop,
    required this.withoutParentLink,
    required this.payingActive,
    required this.freeActive,
  });

  final int totalActive;
  final int newThisMonth;
  final int totalInactive;
  final int withoutActiveWorkshop;
  final int withoutParentLink;

  /// Active children with `payment_type = 'paid'` (regular paying members).
  final int payingActive;

  /// Active children with `payment_type = 'free'` (sponsored / family
  /// friend / scholarship). Excluded from every financial section.
  final int freeActive;
}

class ReportWorkshopTypeStat {
  const ReportWorkshopTypeStat({required this.type, required this.count});
  final String type;
  final int count;
}

class ReportPopularWorkshop {
  const ReportPopularWorkshop({
    required this.title,
    required this.attendees,
  });
  final String title;
  final int attendees;
}

class ReportWorkshopsStatus {
  const ReportWorkshopsStatus({
    required this.sessionsHeld,
    required this.byType,
    required this.mostPopular,
    required this.withoutChildren,
    required this.withoutTrainer,
  });

  final int sessionsHeld;
  final List<ReportWorkshopTypeStat> byType;
  final List<ReportPopularWorkshop> mostPopular;
  final int withoutChildren;
  final int withoutTrainer;
}

class ReportNamedCount {
  const ReportNamedCount({required this.name, required this.count});
  final String name;
  final int count;
}

class ReportNamedRate {
  const ReportNamedRate({
    required this.name,
    required this.ratePercent,
    required this.totalSessions,
  });
  final String name;
  final int ratePercent;
  final int totalSessions;
}

class ReportAttendanceStatus {
  const ReportAttendanceStatus({
    required this.totalPresent,
    required this.totalAbsent,
    required this.totalMotivated,
    required this.attendanceRate,
    required this.topChildrenByAttendance,
    required this.topChildrenByAbsences,
    required this.workshopsWithHighAbsenceRate,
  });

  final int totalPresent;
  final int totalAbsent;
  final int totalMotivated;

  /// 0–100, null when totals are zero.
  final int? attendanceRate;

  final List<ReportNamedRate> topChildrenByAttendance;
  final List<ReportNamedCount> topChildrenByAbsences;
  final List<ReportNamedRate> workshopsWithHighAbsenceRate;
}

class ReportPaymentMethodCount {
  const ReportPaymentMethodCount({required this.method, required this.count});

  /// Display label: 'POS', 'OP', or 'Necunoscut'.
  final String method;
  final int count;
}

class ReportPaymentsStatus {
  const ReportPaymentsStatus({
    required this.paidCycles,
    required this.unconfirmedCycles,
    required this.advancePaidCycles,
    required this.cancelledCycles,
    required this.childrenWithUnconfirmedPayments,
    required this.paymentMethods,
  });

  /// `paid` cycles whose `paid_at` falls inside the selected month.
  final int paidCycles;

  /// `due` + `overdue` cycles whose period intersects the month.
  final int unconfirmedCycles;

  /// `paid_advance` cycles created or paid during the month.
  final int advancePaidCycles;

  final int cancelledCycles;

  /// Names of children whose `due` / `overdue` cycle touches the month.
  final List<String> childrenWithUnconfirmedPayments;

  /// Bucketed counts: 'POS', 'OP', 'Necunoscut' — for paid cycles in
  /// the month.
  final List<ReportPaymentMethodCount> paymentMethods;
}

class ReportTrainerStat {
  const ReportTrainerStat({
    required this.name,
    required this.sessions,
    required this.attendanceMarked,
    required this.activeWorkshops,
  });
  final String name;
  final int sessions;
  final int attendanceMarked;
  final int activeWorkshops;
}

class ReportTrainersStatus {
  const ReportTrainersStatus({
    required this.totalTrainers,
    required this.perTrainer,
  });
  final int totalTrainers;
  final List<ReportTrainerStat> perTrainer;
}

class ReportParentPortalStatus {
  const ReportParentPortalStatus({
    required this.totalParentAccounts,
    required this.activatedParents,
    required this.pendingInvitations,
    required this.expiredInvitations,
    required this.childrenLinkedToParent,
    required this.childrenWithoutParentLink,
  });

  /// Total `profiles` rows with `role = 'parent'`.
  final int totalParentAccounts;

  /// Parents who have completed setup at least once
  /// (`parent_setup_tokens.consumed_at IS NOT NULL`).
  final int activatedParents;

  /// Open invitations that are still within their 24h TTL.
  final int pendingInvitations;

  /// Open invitations whose `expires_at` has elapsed AND whose owner
  /// has not subsequently activated via another token.
  final int expiredInvitations;

  /// Distinct children that have at least one row in `child_parents`.
  final int childrenLinkedToParent;

  /// Active children with no `child_parents` row.
  final int childrenWithoutParentLink;

  /// Activation rate (`activatedParents / totalParentAccounts * 100`),
  /// rounded; null when no parent accounts exist yet.
  int? get activationRatePercent {
    if (totalParentAccounts == 0) return null;
    return ((activatedParents / totalParentAccounts) * 100).round();
  }
}
