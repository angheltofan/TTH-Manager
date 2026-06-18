/// A single chat turn inside the TTH Assistant.
///
/// Messages are persisted in `public.assistant_messages` once the parent
/// conversation has been created. The Edge Function receives the
/// minimal `{role, content}` shape; `sources` and `timestamp` are
/// local-only / display-only and never sent back to OpenAI.
enum AssistantRole { user, assistant }

class AssistantMessage {
  const AssistantMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.sources = const [],
  });

  final AssistantRole role;
  final String content;
  final DateTime timestamp;

  /// Romanian-language data-source labels (e.g. `["Prezențe", "Plăți"]`)
  /// returned by the Edge Function alongside the assistant's reply.
  /// Empty for user messages and for assistant replies that were produced
  /// without calling any tool.
  final List<String> sources;

  /// Serialises to the wire shape expected by the `tth_assistant` Edge
  /// Function. The function receives the full transcript on every
  /// request — stateless on the server.
  Map<String, dynamic> toEdgePayload() => {
        'role': role == AssistantRole.user ? 'user' : 'assistant',
        'content': content,
      };

  /// Parse a row from `public.assistant_messages` into a domain object.
  factory AssistantMessage.fromDbRow(Map<String, dynamic> row) {
    final rawRole = (row['role'] as String?) ?? 'user';
    final role =
        rawRole == 'assistant' ? AssistantRole.assistant : AssistantRole.user;
    final created = row['created_at'];
    return AssistantMessage(
      role: role,
      content: (row['content'] as String?) ?? '',
      timestamp:
          created is String ? (DateTime.tryParse(created) ?? DateTime.now()) : DateTime.now(),
      sources: _parseSources(row['sources']),
    );
  }

  static List<String> _parseSources(dynamic raw) {
    if (raw is List) {
      return raw
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList(growable: false);
    }
    return const [];
  }
}
