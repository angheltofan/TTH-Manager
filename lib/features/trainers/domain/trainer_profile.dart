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
  final int workshopsCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get fullName => '$firstName $lastName';

  factory TrainerProfile.fromMap(Map<String, dynamic> map) {
    // Embedded count: scheduled_workshops: [{count: N}]
    int workshops = 0;
    final raw = map['scheduled_workshops'];
    if (raw is List && raw.isNotEmpty && raw[0] is Map) {
      workshops = ((raw[0] as Map)['count'] as num?)?.toInt() ?? 0;
    }

    return TrainerProfile(
      id: map['id'] as String,
      firstName: (map['first_name'] as String?) ?? '',
      lastName: (map['last_name'] as String?) ?? '',
      role: (map['role'] as String?) ?? 'trainer',
      workshopsCount: workshops,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }
}
