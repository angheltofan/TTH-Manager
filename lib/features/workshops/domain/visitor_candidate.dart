/// A child eligible to be added as a visitor ("Prezență în altă grupă")
/// to a physical workshop session. The child holds at least one active
/// workshop_enrollment on a DIFFERENT series of the SAME workshop_type.
///
/// If [enrollments] contains more than one entry, the picker must force
/// the user to disambiguate before scheduling — the chosen enrollment's
/// series_id becomes `attendance.credited_series_id` on the server.
class VisitorCandidate {
  const VisitorCandidate({
    required this.childId,
    required this.firstName,
    required this.lastName,
    required this.enrollments,
  });

  final String childId;
  final String? firstName;
  final String? lastName;
  final List<VisitorCandidateEnrollment> enrollments;

  String get fullName {
    final fn = (firstName ?? '').trim();
    final ln = (lastName ?? '').trim();
    final full = '$fn $ln'.trim();
    return full.isEmpty ? '(fără nume)' : full;
  }

  bool get needsEnrollmentChoice => enrollments.length > 1;
}

class VisitorCandidateEnrollment {
  const VisitorCandidateEnrollment({
    required this.seriesId,
    required this.seriesTitle,
    required this.dayOfWeek,
    required this.startTime,
  });

  final String seriesId;
  final String seriesTitle;
  final String dayOfWeek;
  final String startTime;

  /// Short human label used in both the picker and the roster subtitle,
  /// e.g. "Marți 16:00". The day label matches `_roWeekdaysShort` in
  /// the activity calendar section.
  String get regularGroupLabel {
    final day = _dayLabels[dayOfWeek] ?? dayOfWeek;
    return '$day $startTime'.trim();
  }
}

const Map<String, String> _dayLabels = {
  'LUNI': 'Luni',
  'MARTI': 'Marți',
  'MIERCURI': 'Miercuri',
  'JOI': 'Joi',
  'VINERI': 'Vineri',
  'SAMBATA': 'Sâmbătă',
  'DUMINICA': 'Duminică',
};
