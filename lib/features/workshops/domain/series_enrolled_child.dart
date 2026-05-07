/// A child enrolled in a workshop series.
/// Parsed from workshop_enrollments joined with children.
class SeriesEnrolledChild {
  const SeriesEnrolledChild({
    required this.enrollmentId,
    required this.childId,
    required this.firstName,
    required this.lastName,
    required this.isEnrollmentActive,
    this.isChildActive,
  });

  final String enrollmentId;
  final String childId;
  final String firstName;
  final String lastName;
  final bool isEnrollmentActive;
  final bool? isChildActive;

  String get fullName => '$firstName $lastName';

  factory SeriesEnrolledChild.fromMap(Map<String, dynamic> map) {
    final child = map['children'] as Map<String, dynamic>?;
    return SeriesEnrolledChild(
      enrollmentId: map['id'] as String,
      childId: map['child_id'] as String,
      firstName: (child?['first_name'] as String?) ?? '',
      lastName: (child?['last_name'] as String?) ?? '',
      isEnrollmentActive: (map['is_active'] as bool?) ?? true,
      isChildActive: child?['is_active'] as bool?,
    );
  }
}
