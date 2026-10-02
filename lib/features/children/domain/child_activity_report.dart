/// Domain model bundle for the Child Activity Report PDF.
///
/// All fields are pre-resolved display values — no UUIDs, no raw nulls.
/// The PDF service consumes this directly; it never reaches back into the
/// database. The repository is the single integration point.
///
/// Afterschool participation is a first-class part of the report:
/// `activeAfterschoolPrograms` lists currently-enrolled programs with
/// their schedule; `afterschoolMonths` carries per-(program, year,
/// month) attendance snapshots computed with the SAME helper the UI
/// uses (`computeAfterschoolMonthAttendance`), so the PDF and the
/// child profile never disagree. Afterschool payments are
/// deliberately NOT in the model — the product has no payment surface
/// on Afterschool.
class ChildActivityReportData {
  const ChildActivityReportData({
    required this.childInfo,
    required this.activeWorkshops,
    required this.activeAfterschoolPrograms,
    required this.attendanceRows,
    required this.afterschoolMonths,
    required this.paymentRows,
    required this.observations,
    required this.summary,
    required this.generatedAt,
  });

  final ChildReportChildInfo childInfo;
  final List<ChildReportWorkshopInfo> activeWorkshops;

  /// Afterschool programs the child is currently enrolled in. Empty
  /// for workshop-only children.
  final List<ChildReportAfterschoolProgramInfo> activeAfterschoolPrograms;

  /// Workshop attendance rows + Afterschool attendance rows merged
  /// into a single history, sorted newest first by the repository.
  final List<ChildReportAttendanceRow> attendanceRows;

  /// Per-(program, year, month) Afterschool attendance snapshots, in
  /// descending calendar order with the newest month first.
  final List<ChildReportAfterschoolMonth> afterschoolMonths;

  final List<ChildReportPaymentRow> paymentRows;
  final List<ChildReportObservation> observations;
  final ChildReportSummary summary;
  final DateTime generatedAt;
}

class ChildReportChildInfo {
  const ChildReportChildInfo({
    required this.id,
    required this.fullName,
    this.birthDate,
    this.age,
    this.parentName,
    this.parentPhone,
    this.parentEmail,
  });

  final String id;
  final String fullName;
  final DateTime? birthDate;
  final int? age;
  final String? parentName;
  final String? parentPhone;
  final String? parentEmail;
}

class ChildReportWorkshopInfo {
  const ChildReportWorkshopInfo({
    required this.title,
    this.workshopType,
    this.dayOfWeek,
    this.startTime,
    this.endTime,
    this.trainerName,
  });

  final String title;
  final String? workshopType;
  final String? dayOfWeek;
  final String? startTime;
  final String? endTime;
  final String? trainerName;
}

class ChildReportAttendanceRow {
  const ChildReportAttendanceRow({
    this.date,
    required this.workshopTitle,
    this.workshopType,
    this.trainerName,
    this.startTime,
    this.endTime,
    required this.status,
    this.observation,
  });

  final DateTime? date;
  final String workshopTitle;
  final String? workshopType;
  final String? trainerName;
  final String? startTime;
  final String? endTime;

  /// Raw status from `attendance.status`: 'present' / 'absent' / 'motivated'.
  final String status;
  final String? observation;
}

class ChildReportPaymentRow {
  const ChildReportPaymentRow({
    this.periodStart,
    this.periodEnd,
    this.sessionsCount,
    this.status,
    this.paymentMethod,
    this.paidAt,
    this.notes,
    this.seriesTitle,
  });

  final DateTime? periodStart;
  final DateTime? periodEnd;
  final int? sessionsCount;

  /// Raw status from `payment_cycles.status`: 'paid' / 'paid_advance' / 'due'
  /// / 'overdue' / 'cancelled'.
  final String? status;

  /// Raw method from `payment_cycles.payment_method`: 'pos' / 'op' / null.
  final String? paymentMethod;
  final DateTime? paidAt;
  final String? notes;
  /// Workshop series title (joined from workshop_series.title). Used to
  /// group cycles per series in the PDF. Nullable for legacy rows.
  final String? seriesTitle;
}

class ChildReportObservation {
  const ChildReportObservation({
    this.date,
    required this.workshopTitle,
    required this.text,
  });

  final DateTime? date;
  final String workshopTitle;
  final String text;
}

class ChildReportSummary {
  const ChildReportSummary({
    required this.totalSessions,
    required this.presentCount,
    required this.absentCount,
    required this.motivatedCount,
    required this.attendanceRate,
    required this.totalWorkshops,
    required this.totalPaymentCycles,
    required this.confirmedPayments,
    required this.overduePayments,
    required this.afterschoolPresentCount,
    required this.afterschoolAbsentCount,
    required this.afterschoolUnmarkedCount,
    required this.afterschoolPlannedCount,
    required this.afterschoolProgramsCount,
    this.afterschoolLastPresenceDate,
  });

  /// Count of workshop attendance rows considered (`present` +
  /// `absent` + `motivated`).
  final int totalSessions;
  final int presentCount;
  final int absentCount;
  final int motivatedCount;

  /// 0.0–1.0 (presentCount / totalSessions) for WORKSHOPS. Null-safe:
  /// zero when no workshop sessions are recorded, so the PDF can
  /// format unconditionally. Afterschool has its own ratios surfaced
  /// per-month inside the SITUAȚIE AFTERSCHOOL section.
  final double attendanceRate;

  /// Distinct workshop series the child has ever attended (by title).
  final int totalWorkshops;
  final int totalPaymentCycles;
  final int confirmedPayments;
  final int overduePayments;

  /// Afterschool aggregates across every (program, month) the child
  /// participated in. Future-scheduled days land in
  /// [afterschoolPlannedCount] — they are NEVER counted as absences.
  final int afterschoolPresentCount;
  final int afterschoolAbsentCount;
  final int afterschoolUnmarkedCount;
  final int afterschoolPlannedCount;

  /// Distinct Afterschool programs the child has ever participated in.
  final int afterschoolProgramsCount;

  /// Most recent past-or-today day the child was marked present at
  /// any Afterschool program.
  final DateTime? afterschoolLastPresenceDate;

  bool get hasWorkshopActivity => totalSessions > 0;
  bool get hasAfterschoolActivity =>
      afterschoolPresentCount > 0 ||
      afterschoolAbsentCount > 0 ||
      afterschoolUnmarkedCount > 0 ||
      afterschoolPlannedCount > 0 ||
      afterschoolProgramsCount > 0;

  bool get hasActivity => hasWorkshopActivity || hasAfterschoolActivity;
}

/// One Afterschool program the child is enrolled in RIGHT NOW. Carries
/// enough schedule context to render alongside workshop entries in the
/// "PROGRAME ACTIVE" section. Deliberately does NOT include fee /
/// price fields — Afterschool is attendance-only in this application.
class ChildReportAfterschoolProgramInfo {
  const ChildReportAfterschoolProgramInfo({
    required this.programName,
    required this.daysOfWeekLabel,
    required this.startTime,
    required this.endTime,
  });

  final String programName;
  final String daysOfWeekLabel;
  final String startTime;
  final String endTime;
}

/// Attendance snapshot for one (program, year, month) tuple — the
/// same shape as `AfterschoolMonthAttendance` on the UI side, but
/// reduced to the pre-formatted values the PDF needs.
///
/// Semantics (shared with the UI's Afterschool child-detail panel):
///   * expected = past-or-today days the child was eligible for;
///   * present + absent + unmarked = expected (invariant);
///   * plannedFuture = future-scheduled days — NEVER an absence;
///   * lastPresenceDate = newest past-or-today day marked present.
class ChildReportAfterschoolMonth {
  const ChildReportAfterschoolMonth({
    required this.programId,
    required this.programName,
    required this.year,
    required this.month,
    required this.expected,
    required this.present,
    required this.absent,
    required this.unmarked,
    required this.plannedFuture,
    this.lastPresenceDate,
  });

  final String programId;
  final String programName;
  final int year;
  final int month;

  final int expected;
  final int present;
  final int absent;
  final int unmarked;
  final int plannedFuture;
  final DateTime? lastPresenceDate;
}
