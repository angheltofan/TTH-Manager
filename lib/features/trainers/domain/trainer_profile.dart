class TrainerProfile {
  const TrainerProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.workshopsCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String role;

  /// Number of active recurring [workshop_series] assigned to this profile.
  /// Set by the repository; always 0 when built from raw map without a join.
  final int workshopsCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get fullName => '$firstName $lastName';

  factory TrainerProfile.fromMap(Map<String, dynamic> map) {
    return TrainerProfile(
      id: map['id'] as String,
      firstName: (map['first_name'] as String?) ?? '',
      lastName: (map['last_name'] as String?) ?? '',
      role: (map['role'] as String?) ?? 'trainer',
      workshopsCount: 0, // Count is always set by the repository layer.
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String)
          : null,
    );
  }
}
