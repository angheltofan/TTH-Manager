import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/team_chat_message.dart';

class TeamChatRepository {
  const TeamChatRepository(this._client);

  final SupabaseClient _client;

  /// Name of the private Supabase Storage bucket holding team-chat
  /// attachments. See [supabase/migrations/20260622_team_chat_attachments_PROPOSED.sql]
  /// for the bucket definition + RLS policies.
  static const String _bucket = 'team-chat-attachments';

  static const _select =
      'id, sender_id, body, created_at, '
      'attachment_url, attachment_name, attachment_size, attachment_kind, '
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

  /// Uploads [bytes] to the team-chat bucket under `{senderId}/{path}`
  /// and returns a long-lived signed URL the bubble can render
  /// without further auth. The bucket is private so a plain public
  /// URL would not resolve; signed URLs preserve "only staff can
  /// read" semantics enforced server-side by the bucket's RLS.
  ///
  /// [contentType] is set as the object's `Content-Type` header so
  /// the browser inlines images / opens PDFs correctly.
  ///
  /// Throws on any storage error — callers should catch and surface a
  /// friendly UI message.
  Future<UploadedAttachment> uploadAttachment({
    required Uint8List bytes,
    required String fileName,
    required ChatAttachmentKind kind,
    String? contentType,
  }) async {
    final senderId = _client.auth.currentUser?.id;
    if (senderId == null) {
      throw StateError(
          'Cannot upload chat attachment — no authenticated user.');
    }

    // Path: {sender_id}/{yyyy}/{mm}/{epochms}-{safeName}
    // The leading {sender_id} folder is required by the storage RLS
    // INSERT policy and prevents one user from over-writing another's
    // objects.
    final now = DateTime.now().toUtc();
    final yyyy = now.year.toString().padLeft(4, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final safeName = fileName.replaceAll(RegExp(r'[^\w\.-]+'), '_');
    final path =
        '$senderId/$yyyy/$mm/${now.millisecondsSinceEpoch}-$safeName';

    await _client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: false,
            cacheControl: '3600',
          ),
        );

    // Signed URL valid for 30 days — long enough that the bubble link
    // stays usable across deep-link shares; short enough that revoking
    // a user's profile expires their attachments eventually.
    final signed = await _client.storage
        .from(_bucket)
        .createSignedUrl(path, 60 * 60 * 24 * 30);

    return UploadedAttachment(
      url: signed,
      name: fileName,
      size: bytes.lengthInBytes,
      kind: kind,
    );
  }

  /// Inserts a new message. Either [body] or [attachment] (or both)
  /// must be present — the server's `payload_present_chk` CHECK
  /// enforces the same rule.
  ///
  /// `sender_id` is derived from the current Supabase auth user. RLS
  /// (`team_chat_insert_staff_self`) additionally enforces
  /// `sender_id = auth.uid()` server-side.
  Future<void> sendMessage({
    String? body,
    UploadedAttachment? attachment,
  }) async {
    final senderId = _client.auth.currentUser?.id;
    if (senderId == null) {
      throw StateError(
        'Cannot send chat message — no authenticated user.',
      );
    }
    final trimmed = body?.trim();
    final hasText = trimmed != null && trimmed.isNotEmpty;
    if (!hasText && attachment == null) {
      throw ArgumentError('Message must carry text or an attachment.');
    }
    final payload = <String, dynamic>{
      'sender_id': senderId,
      // Empty string would violate the payload_present_chk; send null
      // when the message is attachment-only.
      'body': hasText ? trimmed : null,
      'is_deleted': false,
      if (attachment != null) ...{
        'attachment_url': attachment.url,
        'attachment_name': attachment.name,
        'attachment_size': attachment.size,
        'attachment_kind': attachment.kind.value,
      },
    };
    await _client.from('team_chat_messages').insert(payload);
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
    required bool isStaff,
    bool isAdmin = false,
  }) async {
    if (!isStaff) throw StateError('Unauthorized role');
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

/// Bundle returned by [TeamChatRepository.uploadAttachment]. The composer
/// hands this back to [TeamChatRepository.sendMessage] so the upload step
/// and the insert step stay independent (and easy to surface progress
/// for in the UI).
class UploadedAttachment {
  const UploadedAttachment({
    required this.url,
    required this.name,
    required this.size,
    required this.kind,
  });

  final String url;
  final String name;
  final int size;
  final ChatAttachmentKind kind;
}
