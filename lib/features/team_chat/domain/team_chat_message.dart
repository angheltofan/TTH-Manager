/// Kind of attachment carried by a [TeamChatMessage]. Mirrors the
/// CHECK constraint on `team_chat_messages.attachment_kind` —
/// `'image'` triggers an in-bubble preview; `'file'` triggers the
/// download card.
enum ChatAttachmentKind {
  image,
  file;

  static ChatAttachmentKind? parse(String? raw) {
    switch (raw) {
      case 'image':
        return ChatAttachmentKind.image;
      case 'file':
        return ChatAttachmentKind.file;
      default:
        return null;
    }
  }

  String get value => name;
}

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
    this.attachmentUrl,
    this.attachmentName,
    this.attachmentSize,
    this.attachmentKind,
  });

  final String id;
  final String senderId;

  /// Optional now that messages may be attachment-only.
  /// Empty string is treated as "no caption" by the UI.
  final String body;
  final DateTime createdAt;
  final String? senderFirstName;
  final String? senderLastName;
  final String? senderRole;

  /// Public (or signed) URL of the uploaded object.
  final String? attachmentUrl;

  /// Original filename, used as the file-card title and as a fallback
  /// for the download filename if the browser/OS asks.
  final String? attachmentName;

  /// Byte size — formatted by the UI as "12.4 MB" etc. when present.
  final int? attachmentSize;

  /// 'image' or 'file'. When null the row is text-only.
  final ChatAttachmentKind? attachmentKind;

  bool get hasAttachment => attachmentUrl != null && attachmentKind != null;
  bool get isImageAttachment =>
      hasAttachment && attachmentKind == ChatAttachmentKind.image;
  bool get isFileAttachment =>
      hasAttachment && attachmentKind == ChatAttachmentKind.file;
  bool get hasText => body.trim().isNotEmpty;

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
    final rawSize = map['attachment_size'];
    final size = rawSize is int
        ? rawSize
        : (rawSize is num ? rawSize.toInt() : null);
    return TeamChatMessage(
      id: map['id'] as String,
      senderId: map['sender_id'] as String,
      body: (map['body'] as String?) ?? '',
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      senderFirstName: firstName,
      senderLastName: lastName,
      senderRole: role,
      attachmentUrl: map['attachment_url'] as String?,
      attachmentName: map['attachment_name'] as String?,
      attachmentSize: size,
      attachmentKind:
          ChatAttachmentKind.parse(map['attachment_kind'] as String?),
    );
  }
}
