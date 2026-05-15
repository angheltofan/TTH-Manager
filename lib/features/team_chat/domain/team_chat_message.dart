/// Domain model for a row in `public.team_chat_messages`.
class TeamChatMessage {
  const TeamChatMessage({
    required this.id,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.senderFirstName,
    this.senderLastName,
    this.senderRole,
  });

  final String id;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final String? senderFirstName;
  final String? senderLastName;
  final String? senderRole;

  String get senderName {
    final fn = senderFirstName ?? '';
    final ln = senderLastName ?? '';
    final full = '$fn $ln'.trim();
    return full.isEmpty ? 'Utilizator' : full;
  }

  String get initials {
    final fn = senderFirstName?.isNotEmpty == true ? senderFirstName![0] : '';
    final ln = senderLastName?.isNotEmpty == true ? senderLastName![0] : '';
    final ini = '$fn$ln'.toUpperCase();
    return ini.isEmpty ? '?' : ini;
  }

  factory TeamChatMessage.fromMap(Map<String, dynamic> map) {
    String? firstName, lastName, role;
    final profile = map['profiles'];
    if (profile is Map) {
      firstName = profile['first_name'] as String?;
      lastName = profile['last_name'] as String?;
      role = profile['role'] as String?;
    }
    return TeamChatMessage(
      id: map['id'] as String,
      senderId: map['sender_id'] as String,
      body: map['body'] as String,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      senderFirstName: firstName,
      senderLastName: lastName,
      senderRole: role,
    );
  }
}
