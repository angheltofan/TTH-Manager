// Domain models for the parent dashboard.
//
// All data is composed from PostgREST queries against tables for which
// the parent role has explicit P2 SELECT policies:
//   • child_parents, children, attendance, payment_cycles,
//     workshop_enrollments, scheduled_workshops, notifications.
//
// Notes:
//   • Trainer names: best-effort. Parent role has no SELECT on staff
//     profile rows, so the JOIN returns null. The UI hides the trainer
//     line when `trainerName == null`.
//   • Workshop titles come from `scheduled_workshops.title`
//     (denormalised) so we don't need parent SELECT on workshop_series.

// ── Per-child workshop summary (next instance metadata) ─────────────────────

/// Compact view of one of a child's currently-enrolled workshops, derived
/// from the next upcoming `scheduled_workshops` row whose `series_id` or
/// `recurring_series_id` matches the enrollment. Used by the dashboard's
/// per-child card so the title/day/time are shown without an extra query.
class ParentChildWorkshopBrief {
  const ParentChildWorkshopBrief({
    this.title,
    this.workshopType,
    this.dayOfWeek,
    this.startTime,
    this.endTime,
    this.trainerName,
  });

  /// `scheduled_workshops.title` (denormalised from the series).
  final String? title;

  /// `scheduled_workshops.workshop_type` — used as a fallback when title
  /// is missing.
  final String? workshopType;

  /// `scheduled_workshops.day_of_week` (Romanian, e.g. "Luni").
  final String? dayOfWeek;

  /// `'HH:MM:SS'` strings; formatted by the UI via `formatTimeString`.
  final String? startTime;
  final String? endTime;

  /// `profiles.first_name + last_name` for the trainer assigned on the
  /// `workshop_series` row, or null when the parent has no RLS access
  /// to that staff profile.
  final String? trainerName;

  /// Display label fallback chain.
  String displayLabel() =>
      (title?.isNotEmpty == true) ? title! : (workshopType ?? 'Atelier');
}

// ── Linked child summary on the dashboard card ──────────────────────────────

class ParentDashboardChild {
  const ParentDashboardChild({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.isPrimary = false,
    this.paymentType = 'paid',
    required this.activeWorkshopCount,
    required this.currentCyclePresent,
    this.currentCycleTarget = 4,
    this.paymentStatus,
    this.paymentMethod,
    this.paymentPaidAt,
    this.primaryWorkshop,
    this.nextWorkshopDate,
  });

  final String id;
  final String firstName;
  final String lastName;
  final bool isPrimary;

  /// `'paid'` or `'free'`. When `'free'`, the dashboard card hides the
  /// payment block and the "...până la plată" countdown helper, and
  /// the repository windows [currentCyclePresent] client-side because
  /// no payment_cycles row is ever written for free children.
  final String paymentType;

  bool get isFreeParticipant => paymentType == 'free';

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

  /// Latest `payment_cycles.payment_method` (e.g. 'pos', 'op'). Mapped
  /// to a "POS"/"OP" display suffix by the canonical `resolvePaymentLabel`
  /// helper. Null when the column is blank — the suffix is then omitted.
  final String? paymentMethod;

  /// Latest `payment_cycles.paid_at` — when applicable, surfaces the
  /// confirmation date in the payment helper line.
  final DateTime? paymentPaidAt;

  /// One representative workshop (the next upcoming one) — used in the
  /// per-child card to show title/day/time. Null when child has no
  /// active enrollments.
  final ParentChildWorkshopBrief? primaryWorkshop;

  /// Date of `primaryWorkshop` next session — used to pick the focal
  /// child for parent-level KPI cards (the child with the nearest
  /// upcoming workshop). Null when no upcoming session exists.
  final DateTime? nextWorkshopDate;

  /// Number of OTHER active enrollments beyond [primaryWorkshop].
  /// Equal to `max(0, activeWorkshopCount - 1)` and surfaced as a
  /// "+N atelier(e)" badge in the UI.
  int get additionalWorkshopCount =>
      activeWorkshopCount > 1 ? activeWorkshopCount - 1 : 0;

  /// Remaining sessions until the next payment-close (e.g. 4 - 2 = 2).
  /// Clamped at 0.
  int get sessionsRemaining {
    final r = currentCycleTarget - currentCyclePresent;
    return r < 0 ? 0 : r;
  }

  String get fullName {
    final f = firstName.trim();
    final l = lastName.trim();
    if (f.isEmpty && l.isEmpty) return '';
    if (l.isEmpty) return f;
    if (f.isEmpty) return l;
    return '$f $l';
  }
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
    this.trainerName,
  });

  final String id;
  final String? title;
  final String? workshopType;
  final DateTime? workshopDate;
  final String? dayOfWeek;
  final String? startTime;
  final String? endTime;
  final bool isActive;

  /// Best-effort; null when RLS blocks parent access to staff profile.
  final String? trainerName;

  factory ParentNextWorkshop.fromMap(Map<String, dynamic> map) {
    final trainer = map['profiles'] as Map<String, dynamic>?;
    String? trainerName;
    if (trainer != null) {
      final f = (trainer['first_name'] as String?)?.trim() ?? '';
      final l = (trainer['last_name'] as String?)?.trim() ?? '';
      final composed = ('$f $l').trim();
      trainerName = composed.isEmpty ? null : composed;
    }
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
      trainerName: trainerName,
    );
  }
}

// ── Recent activity item (one row in the dashboard feed) ──────────────────

/// Single row in the dashboard's "Activitate recentă" section. Joins
/// `attendance` to the parent's child + the scheduled workshop so the
/// row carries enough context to render without further lookups.
class ParentRecentActivityItem {
  const ParentRecentActivityItem({
    required this.id,
    required this.childId,
    required this.childFirstName,
    required this.childLastName,
    this.status,
    this.workshopTitle,
    this.workshopType,
    this.workshopDate,
    this.dayOfWeek,
    this.startTime,
    this.endTime,
    this.markedAt,
    this.observation,
  });

  final String id;
  final String childId;
  final String childFirstName;
  final String childLastName;
  final String? status; // 'present' | 'absent' | 'motivated'
  final String? workshopTitle;
  final String? workshopType;
  final DateTime? workshopDate;
  final String? dayOfWeek;
  final String? startTime;
  final String? endTime;
  final DateTime? markedAt;
  final String? observation;

  String get childFullName {
    final f = childFirstName.trim();
    final l = childLastName.trim();
    if (f.isEmpty && l.isEmpty) return '';
    if (l.isEmpty) return f;
    if (f.isEmpty) return l;
    return '$f $l';
  }

  String get workshopLabel =>
      (workshopTitle?.isNotEmpty == true) ? workshopTitle! : (workshopType ?? 'atelier');
}

// ── KPI: nearest upcoming workshop across ALL of the parent's children ─────

/// Parent-level "Următorul atelier" KPI payload. Carries the soonest
/// upcoming `scheduled_workshops` row matched against any of the
/// parent's children's active enrollments, plus the first names of the
/// children who attend that specific session so the KPI can tell the
/// parent "for whom".
///
/// `additionalUpcomingCount` is how many OTHER distinct upcoming
/// sessions the parent has after this one — drives the optional
/// "+ încă N atelier(e)" helper in the UI.
class ParentNextWorkshopSummary {
  const ParentNextWorkshopSummary({
    required this.scheduledWorkshopId,
    this.title,
    this.workshopType,
    this.workshopDate,
    this.dayOfWeek,
    this.startTime,
    this.endTime,
    this.childNames = const [],
    this.additionalUpcomingCount = 0,
  });

  final String scheduledWorkshopId;
  final String? title;
  final String? workshopType;
  final DateTime? workshopDate;
  final String? dayOfWeek;
  final String? startTime;
  final String? endTime;

  /// First names of the parent's linked children attending THIS
  /// session, in primary-first order.
  final List<String> childNames;

  /// Count of OTHER upcoming sessions (after this one) the parent has
  /// across all linked children. 0 when there are no further upcoming
  /// sessions in the lookahead window.
  final int additionalUpcomingCount;

  String get displayLabel =>
      (title?.isNotEmpty == true) ? title! : (workshopType ?? 'Atelier');
}

// ── KPI: parent-level attendance rate (last 30 days) ────────────────────────

/// Last-30-days attendance counts across every linked child of the
/// parent. `ratePercent` is null when `totalCount == 0` (no rows to
/// derive a rate from); UI should render "—" or "0%" with a
/// "Fără date recente" subtitle in that case.
class ParentAttendanceRateSummary {
  const ParentAttendanceRateSummary({
    required this.presentCount,
    required this.absentCount,
    required this.motivatedCount,
    required this.totalCount,
    required this.ratePercent,
  });

  const ParentAttendanceRateSummary.empty()
      : presentCount = 0,
        absentCount = 0,
        motivatedCount = 0,
        totalCount = 0,
        ratePercent = null;

  final int presentCount;
  final int absentCount;
  final int motivatedCount;

  /// `present + absent + motivated`. Other status values (if any) are
  /// excluded from both numerator and denominator.
  final int totalCount;

  /// `presentCount / totalCount * 100`, or null when no rows.
  final double? ratePercent;

  bool get isEmpty => totalCount == 0;

  /// Absent + motivated, treated as "missed" for the subtitle copy.
  int get missedCount => absentCount + motivatedCount;
}

// ── KPI: parent-level payment summary ──────────────────────────────────────

/// Triage state of the parent's payment KPI.
enum ParentPaymentSummaryStatus {
  /// No child has an open `due` or `overdue` cycle.
  ok,

  /// At least one child has `payment_cycles.status == 'due'`. No child
  /// has an overdue cycle.
  due,

  /// At least one child has `payment_cycles.status == 'overdue'`.
  /// Overrides any 'due' rows for the same parent.
  overdue,
}

/// Aggregated payment status across all of the parent's linked
/// children. Derived from `ParentDashboardChild.paymentStatus` (latest
/// cycle per child) — no extra DB query needed.
class ParentPaymentSummary {
  const ParentPaymentSummary({
    required this.status,
    required this.overdueCount,
    required this.dueCount,
    this.affectedChildFirstNames = const [],
  });

  const ParentPaymentSummary.ok()
      : status = ParentPaymentSummaryStatus.ok,
        overdueCount = 0,
        dueCount = 0,
        affectedChildFirstNames = const [];

  final ParentPaymentSummaryStatus status;
  final int overdueCount;
  final int dueCount;

  /// First names of the children driving the current status (overdue
  /// children when status==overdue; due children when status==due;
  /// empty when status==ok). Ordered primary-first.
  final List<String> affectedChildFirstNames;
}

// ── New: weekly session (one row in "Program săptămâna aceasta") ────────────

/// One scheduled session occurring in the visible week. If multiple of
/// the parent's children attend the same session (same
/// `scheduled_workshop_id`), the row carries all their first names so
/// the UI renders them as badges on a single row.
class ParentWeeklySession {
  const ParentWeeklySession({
    required this.scheduledWorkshopId,
    this.title,
    this.workshopType,
    this.workshopDate,
    this.dayOfWeek,
    this.startTime,
    this.endTime,
    this.trainerName,
    this.childFirstNames = const [],
  });

  final String scheduledWorkshopId;
  final String? title;
  final String? workshopType;
  final DateTime? workshopDate;
  final String? dayOfWeek;
  final String? startTime;
  final String? endTime;

  /// Best-effort; null when RLS blocks parent access to staff profile.
  final String? trainerName;

  /// First names of the linked children attending this session, in the
  /// order returned by `getLinkedChildren` (primary first).
  final List<String> childFirstNames;

  String get displayLabel =>
      (title?.isNotEmpty == true) ? title! : (workshopType ?? 'Atelier');
}
