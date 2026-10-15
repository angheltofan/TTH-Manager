/// Domain model for one row of `public.child_progress` enriched with
/// the small amount of session + trainer context the Phase 2 UI needs.
///
/// The three canonical feedback fields — [built], [learned],
/// [parentMessage] — are the Phase 1 schema additions and are each
/// nullable. The legacy [note] column is preserved so older rows (if
/// any) remain readable; new rows written through the Phase 2 flow
/// leave it NULL.
///
/// Session + trainer are flattened to plain strings. They come from
/// a left JOIN in the repository; the model never does its own DB
/// work.
class ChildProgress {
  const ChildProgress({
    required this.id,
    required this.childId,
    required this.scheduledWorkshopId,
    required this.trainerId,
    required this.title,
    required this.note,
    required this.status,
    required this.built,
    required this.learned,
    required this.parentMessage,
    required this.createdAt,
    required this.updatedAt,
    this.sessionTitle,
    this.sessionDate,
    this.sessionStartTime,
    this.sessionEndTime,
    this.trainerFullName,
  });

  final String id;
  final String childId;
  final String? scheduledWorkshopId;
  final String? trainerId;

  final String? title;

  /// Legacy free-text note. Phase 2 writes to [built] / [learned] /
  /// [parentMessage] instead and leaves this NULL. The field stays on
  /// the model so a future admin view can still surface pre-existing
  /// notes.
  final String? note;

  /// One of `in_progress`, `completed`, `needs_review` (enforced by
  /// the DB CHECK on `child_progress.status`).
  final String status;

  /// Short description of what the child built in that session.
  final String? built;

  /// Short description of what the child learned in that session.
  final String? learned;

  /// Short trainer message addressed to the parent.
  final String? parentMessage;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Session title, left-joined from `scheduled_workshops.title`.
  /// Null when the row has no session or the parent cannot see the
  /// joined row.
  final String? sessionTitle;
  final DateTime? sessionDate;
  final String? sessionStartTime;
  final String? sessionEndTime;

  /// Trainer full name, left-joined from `profiles.full_name`. Null
  /// when the parent cannot read the trainer row (expected for the
  /// Parent Portal, since parents have no SELECT on staff profiles).
  final String? trainerFullName;

  bool get hasAnyFeedback =>
      (built?.trim().isNotEmpty ?? false) ||
      (learned?.trim().isNotEmpty ?? false) ||
      (parentMessage?.trim().isNotEmpty ?? false) ||
      (note?.trim().isNotEmpty ?? false);

  factory ChildProgress.fromMap(Map<String, dynamic> map) {
    // scheduled_workshops may embed either as an object (one row) or
    // null when the FK is unresolved / unauthorized.
    final sw = map['scheduled_workshops'];
    Map<String, dynamic>? session;
    if (sw is Map<String, dynamic>) {
      session = sw;
    } else if (sw is List && sw.isNotEmpty) {
      session = sw.first as Map<String, dynamic>?;
    }

    final tr = map['trainer'];
    Map<String, dynamic>? trainer;
    if (tr is Map<String, dynamic>) {
      trainer = tr;
    } else if (tr is List && tr.isNotEmpty) {
      trainer = tr.first as Map<String, dynamic>?;
    }

    DateTime? parseDate(dynamic raw) {
      if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
      return null;
    }

    return ChildProgress(
      id: map['id'] as String,
      childId: map['child_id'] as String,
      scheduledWorkshopId: map['scheduled_workshop_id'] as String?,
      trainerId: map['trainer_id'] as String?,
      title: map['title'] as String?,
      note: map['note'] as String?,
      status: (map['status'] as String?) ?? 'in_progress',
      built: map['built'] as String?,
      learned: map['learned'] as String?,
      parentMessage: map['parent_message'] as String?,
      createdAt: parseDate(map['created_at']) ?? DateTime.now(),
      updatedAt: parseDate(map['updated_at']) ?? DateTime.now(),
      sessionTitle: session?['title'] as String?,
      sessionDate: parseDate(session?['workshop_date']),
      sessionStartTime: session?['start_time'] as String?,
      sessionEndTime: session?['end_time'] as String?,
      trainerFullName: trainer?['full_name'] as String?,
    );
  }
}
