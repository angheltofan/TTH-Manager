class AppProfile {
  const AppProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.createdAt,
    this.updatedAt,
    this.teamChatLastReadAt,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String role;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? teamChatLastReadAt;

  String get fullName => '$firstName $lastName';
  bool get isAdmin => role == 'admin';
  bool get isTrainer => role == 'trainer';

  /// Combined staff predicate. Mirrors the server-side `is_staff()` SQL
  /// helper and is used by repository guards as defense-in-depth alongside
  /// RLS.
  bool get isStaff => isAdmin || isTrainer;

  factory AppProfile.fromMap(Map<String, dynamic> map) {
    return AppProfile(
      id: map['id'] as String,
      firstName: map['first_name'] as String,
      lastName: map['last_name'] as String,
      role: map['role'] as String,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      teamChatLastReadAt: map['team_chat_last_read_at'] != null
          ? DateTime.parse(map['team_chat_last_read_at'] as String)
          : null,
    );
  }
}
