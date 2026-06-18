import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/assistant_conversation.dart';
import '../domain/assistant_message.dart';

/// Wire + persistence layer for the TTH Assistant chat.
///
///   - Conversations and messages live in `public.assistant_*` tables
///     (staff-only RLS).
///   - The Edge Function is stateless: it receives the last ~30 messages
///     each request and returns `{reply, sources}`.
///   - The Edge Function never reads or writes the DB tables itself —
///     this client owns persistence.
class AssistantRepository {
  const AssistantRepository(this._client);

  final SupabaseClient _client;

  // ── Conversations ─────────────────────────────────────────────────────────

  /// Lists every conversation the signed-in staff user owns, newest
  /// activity first. RLS guarantees the result is already scoped to
  /// `auth.uid()`.
  Future<List<AssistantConversation>> fetchConversations() async {
    final data = await _client
        .from('assistant_conversations')
        .select()
        .order('last_message_at', ascending: false, nullsFirst: false)
        .order('updated_at', ascending: false);
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(AssistantConversation.fromRow)
        .toList(growable: false);
  }

  /// Returns the user's most-recent conversation, creating one if they
  /// don't have any yet. Caller must already be authenticated.
  Future<AssistantConversation> getOrCreateLatestConversation(
    String userId,
  ) async {
    final latest = await _client
        .from('assistant_conversations')
        .select()
        .eq('user_id', userId)
        .order('last_message_at', ascending: false, nullsFirst: false)
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (latest != null) {
      return AssistantConversation.fromRow(latest);
    }
    return createConversation(userId);
  }

  Future<AssistantConversation> createConversation(String userId) async {
    final created = await _client
        .from('assistant_conversations')
        .insert({'user_id': userId})
        .select()
        .single();
    return AssistantConversation.fromRow(created);
  }

  Future<AssistantConversation> renameConversation(
    String conversationId,
    String newTitle,
  ) async {
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Title cannot be empty');
    }
    final updated = await _client
        .from('assistant_conversations')
        .update({'title': trimmed})
        .eq('id', conversationId)
        .select()
        .single();
    return AssistantConversation.fromRow(updated);
  }

  Future<AssistantConversation> setFavorite(
    String conversationId, {
    required bool isFavorite,
  }) async {
    final updated = await _client
        .from('assistant_conversations')
        .update({'is_favorite': isFavorite})
        .eq('id', conversationId)
        .select()
        .single();
    return AssistantConversation.fromRow(updated);
  }

  Future<void> deleteConversation(String conversationId) async {
    await _client
        .from('assistant_conversations')
        .delete()
        .eq('id', conversationId);
  }

  // ── Messages ──────────────────────────────────────────────────────────────

  Future<List<AssistantMessage>> fetchMessages(String conversationId) async {
    final data = await _client
        .from('assistant_messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(AssistantMessage.fromDbRow)
        .toList(growable: false);
  }

  Future<AssistantMessage> insertMessage({
    required String conversationId,
    required AssistantRole role,
    required String content,
    List<String> sources = const [],
  }) async {
    final row = await _client
        .from('assistant_messages')
        .insert({
          'conversation_id': conversationId,
          'role': role == AssistantRole.assistant ? 'assistant' : 'user',
          'content': content,
          'sources': sources,
        })
        .select()
        .single();
    return AssistantMessage.fromDbRow(row);
  }

  // ── Edge Function ─────────────────────────────────────────────────────────

  /// Posts [history] (full transcript including the most recent user
  /// message) to the `tth_assistant` Edge Function. Returns both the
  /// Romanian reply and the data-source labels. Throws
  /// [AssistantException] for any non-2xx response.
  ///
  /// `sources` is backward-compatible: a function version that pre-dates
  /// this field is treated as if it returned an empty list.
  Future<AssistantReply> sendMessage(List<AssistantMessage> history) async {
    try {
      final response = await _client.functions.invoke(
        'tth_assistant',
        body: {
          'messages': history.map((m) => m.toEdgePayload()).toList(),
        },
      );

      final status = response.status;
      final data = response.data;
      if (status != 200) {
        throw AssistantException(
          status: status,
          message: _extractError(data, status),
        );
      }
      if (data is! Map<String, dynamic>) {
        throw AssistantException(
          status: status,
          message: 'Răspuns neașteptat de la asistent.',
        );
      }
      final reply = data['reply'];
      if (reply is! String || reply.trim().isEmpty) {
        throw AssistantException(
          status: status,
          message: 'Răspuns gol primit de la asistent.',
        );
      }
      final rawSources = data['sources'];
      final sources = rawSources is List
          ? rawSources
              .map((e) => e?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList(growable: false)
          : const <String>[];
      return AssistantReply(reply: reply, sources: sources);
    } on FunctionException catch (e) {
      throw AssistantException(
        status: e.status,
        message: _extractError(e.details, e.status),
      );
    }
  }

  static String _extractError(dynamic body, int status) {
    if (body is Map) {
      final err = body['error'];
      if (err is String && err.isNotEmpty) return err;
      final msg = body['message'];
      if (msg is String && msg.isNotEmpty) return msg;
    }
    if (body is String && body.isNotEmpty) return body;
    return 'Eroare asistent (status $status).';
  }
}

/// Tuple returned by [AssistantRepository.sendMessage].
class AssistantReply {
  const AssistantReply({required this.reply, required this.sources});
  final String reply;
  final List<String> sources;
}

/// Structured error raised when the `tth_assistant` Edge Function
/// responds with a non-2xx status.
class AssistantException implements Exception {
  const AssistantException({required this.status, required this.message});

  final int status;
  final String message;

  @override
  String toString() => 'AssistantException($status): $message';
}
