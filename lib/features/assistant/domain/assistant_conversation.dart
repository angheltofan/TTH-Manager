/// A persisted TTH Assistant conversation. Owned by exactly one staff
/// user (`profiles.id`); messages live in `public.assistant_messages`
/// and link via `conversation_id`.
class AssistantConversation {
  const AssistantConversation({
    required this.id,
    required this.title,
    required this.isFavorite,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessageAt,
  });

  final String id;
  final String title;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// `null` for conversations that have no messages yet. Sorting in the
  /// conversation list falls back to [updatedAt] in that case.
  final DateTime? lastMessageAt;

  /// Best-effort "activity" timestamp used by the conversation list:
  /// the most recent message, or [updatedAt] as fallback.
  DateTime get activityAt => lastMessageAt ?? updatedAt;

  AssistantConversation copyWith({
    String? title,
    bool? isFavorite,
    DateTime? updatedAt,
    DateTime? lastMessageAt,
  }) {
    return AssistantConversation(
      id: id,
      title: title ?? this.title,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    );
  }

  factory AssistantConversation.fromRow(Map<String, dynamic> row) {
    return AssistantConversation(
      id: row['id'] as String,
      title: (row['title'] as String?)?.trim().isNotEmpty == true
          ? row['title'] as String
          : 'Conversație nouă',
      isFavorite: (row['is_favorite'] as bool?) ?? false,
      createdAt: _parseTs(row['created_at']),
      updatedAt: _parseTs(row['updated_at']),
      lastMessageAt: _parseTsNullable(row['last_message_at']),
    );
  }

  static DateTime _parseTs(dynamic raw) {
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }

  static DateTime? _parseTsNullable(dynamic raw) {
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }
}
