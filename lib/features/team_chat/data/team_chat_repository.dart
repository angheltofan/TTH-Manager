import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/team_chat_message.dart';

class TeamChatRepository {
  const TeamChatRepository(this._client);

  final SupabaseClient _client;

  static const _select =
      'id, sender_id, body, created_at, '
      'profiles!sender_id(first_name, last_name, role)';

  /// Returns the latest [limit] non-deleted messages, ordered oldest → newest.
  Future<List<TeamChatMessage>> fetchMessages({int limit = 100}) async {
    final data = await _client
        .from('team_chat_messages')
        .select(_select)
        .eq('is_deleted', false)
        .order('created_at', ascending: false)
        .limit(limit);
    return (data as List)
        .map((e) => TeamChatMessage.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Inserts a new message. [body] must already be trimmed.
  Future<void> sendMessage({
    required String body,
    required String senderId,
  }) async {
    await _client.from('team_chat_messages').insert({
      'sender_id': senderId,
      'body': body,
      'is_deleted': false,
    });
  }

  /// Soft-deletes a message (does not physically remove it).
  ///
  /// Defense-in-depth alongside RLS:
  ///   • Regular users may only delete their own messages — the update is
  ///     additionally filtered on `sender_id = currentUserId`.
  ///   • Admins may delete any message — the sender filter is skipped when
  ///     [isAdmin] is true. Server-side RLS is still the source of truth.
  Future<void> softDeleteMessage({
    required String messageId,
    required String currentUserId,
    bool isAdmin = false,
  }) async {
    var query = _client
        .from('team_chat_messages')
        .update({'is_deleted': true})
        .eq('id', messageId);
    if (!isAdmin) {
      query = query.eq('sender_id', currentUserId);
    }
    await query;
  }
}
