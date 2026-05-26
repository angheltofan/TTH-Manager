/// One row in `public.child_parents` joined with the linked parent's
/// profile. Used by the admin-side "Părinți asociați" card on the Child
/// Details page.
class ParentLink {
  const ParentLink({
    required this.id,
    required this.parentId,
    required this.firstName,
    required this.lastName,
    this.relationship,
    this.isPrimary = false,
    this.createdAt,
  });

  final String id;
  final String parentId;
  final String firstName;
  final String lastName;
  final String? relationship;
  final bool isPrimary;
  final DateTime? createdAt;

  String get fullName => '$firstName $lastName'.trim();

  factory ParentLink.fromMap(Map<String, dynamic> map) {
    final profile = map['profiles'] as Map<String, dynamic>?;
    return ParentLink(
      id: map['id'] as String,
      parentId: (map['parent_id'] as String?) ?? '',
      firstName: (profile?['first_name'] as String?) ?? '',
      lastName: (profile?['last_name'] as String?) ?? '',
      relationship: map['relationship'] as String?,
      isPrimary: (map['is_primary'] as bool?) ?? false,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
    );
  }
}

/// A `profiles` row with `role='parent'`, used by the "Asociază existent"
/// search picker.
class ParentProfile {
  const ParentProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
  });

  final String id;
  final String firstName;
  final String lastName;

  String get fullName => '$firstName $lastName'.trim();

  factory ParentProfile.fromMap(Map<String, dynamic> map) => ParentProfile(
        id: map['id'] as String,
        firstName: (map['first_name'] as String?) ?? '',
        lastName: (map['last_name'] as String?) ?? '',
      );
}

/// Successful response from the `create_parent_and_link_child` Edge
/// Function. `inviteSent` is true only when a brand-new auth user was
/// created — the dialog uses it to pick the success message.
class ParentInviteResult {
  const ParentInviteResult({
    required this.parentId,
    required this.linkId,
    required this.inviteSent,
  });

  final String parentId;
  final String linkId;
  final bool inviteSent;

  factory ParentInviteResult.fromMap(Map<String, dynamic> map) =>
      ParentInviteResult(
        parentId: map['parent_id'] as String,
        linkId: map['link_id'] as String,
        inviteSent: (map['invite_sent'] as bool?) ?? false,
      );
}

/// Structured error raised when the `create_parent_and_link_child` Edge
/// Function responds with a non-2xx status. Carries the HTTP status so
/// the UI layer can map it to a user-facing message.
class ParentInviteException implements Exception {
  const ParentInviteException({required this.status, required this.message});

  final int status;
  final String message;

  @override
  String toString() => 'ParentInviteException($status): $message';
}
