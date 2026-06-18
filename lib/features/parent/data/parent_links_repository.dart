import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/parent_link.dart';

/// Data layer for the `public.child_parents` table.
///
/// Writes (link/unlink) are admin-only and gated by both:
///   • the `isAdmin` guard inside each method (`StateError` if false), and
///   • the `child_parents_admin_all` RLS policy on the server.
///
/// The "create new parent" path is deliberately not implemented in P4:
/// creating an `auth.users` row requires the Supabase service role and
/// MUST live in an Edge Function. See `prepareCreateParent`.
class ParentLinksRepository {
  const ParentLinksRepository(this._client);

  final SupabaseClient _client;

  // ── Read ───────────────────────────────────────────────────────────────────

  Future<List<ParentLink>> getLinkedParents(String childId) async {
    final data = await _client
        .from('child_parents')
        .select(
            'id, parent_id, relationship, is_primary, created_at, '
            'profiles!parent_id(first_name, last_name, role)')
        .eq('child_id', childId)
        .order('is_primary', ascending: false)
        .order('created_at', ascending: true);
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(ParentLink.fromMap)
        .toList();
  }

  Future<List<ParentProfile>> searchExistingParents(
    String query, {
    required bool isAdmin,
  }) async {
    if (!isAdmin) throw StateError('Unauthorized role');
    final trimmed = query.trim();
    var q = _client
        .from('profiles')
        .select('id, first_name, last_name')
        .eq('role', 'parent');
    if (trimmed.isNotEmpty) {
      final escaped = trimmed.replaceAll('%', '\\%').replaceAll('_', '\\_');
      q = q.or('first_name.ilike.%$escaped%,last_name.ilike.%$escaped%');
    }
    final data =
        await q.order('last_name', ascending: true).limit(50);
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(ParentProfile.fromMap)
        .toList();
  }

  // ── Write ──────────────────────────────────────────────────────────────────

  Future<void> linkExistingParent({
    required bool isAdmin,
    required String childId,
    required String parentId,
    String? relationship,
    bool isPrimary = false,
  }) async {
    if (!isAdmin) throw StateError('Unauthorized role');
    await _client.from('child_parents').upsert(
      {
        'child_id': childId,
        'parent_id': parentId,
        'relationship': relationship,
        'is_primary': isPrimary,
      },
      onConflict: 'child_id,parent_id',
    );
  }

  Future<void> unlinkParent({
    required bool isAdmin,
    required String linkId,
  }) async {
    if (!isAdmin) throw StateError('Unauthorized role');
    await _client.from('child_parents').delete().eq('id', linkId);
  }

  /// Invokes the `create_parent_and_link_child` Supabase Edge Function.
  ///
  /// The Flutter client only ever calls the function; it never holds the
  /// service-role key. The function:
  ///   • verifies the caller's JWT,
  ///   • verifies `is_admin()` server-side,
  ///   • looks up the auth user by email (reuse) or invites one (create),
  ///   • upserts the `profiles` row with `role='parent'`,
  ///   • upserts the `child_parents` link,
  ///   • returns `{ parent_id, link_id, invite_sent }`.
  ///
  /// Throws [ParentInviteException] for any non-2xx response so the UI
  /// can map status → user-facing message. The local `isAdmin` guard
  /// stays as defense-in-depth alongside the server-side check.
  Future<ParentInviteResult> prepareCreateParent({
    required bool isAdmin,
    required String childId,
    required String firstName,
    required String lastName,
    required String email,
    String? relationship,
    bool isPrimary = false,
  }) async {
    if (!isAdmin) throw StateError('Unauthorized role');

    try {
      final response = await _client.functions.invoke(
        'create_parent_and_link_child',
        body: {
          'child_id': childId,
          'first_name': firstName,
          'last_name': lastName,
          'email': email,
          'relationship': ?relationship,
          'is_primary': isPrimary,
        },
      );

      // `supabase_flutter` throws FunctionException for non-2xx responses
      // (handled below); this branch is the defensive fallback if a future
      // SDK release stops throwing or returns a non-200 inside data.
      final status = response.status;
      final data = response.data;
      if (status != 200) {
        throw ParentInviteException(
          status: status,
          message: _extractErrorMessage(data, status),
        );
      }
      if (data is! Map<String, dynamic>) {
        throw ParentInviteException(
          status: status,
          message: 'Răspuns neașteptat de la server.',
        );
      }
      return ParentInviteResult.fromMap(data);
    } on FunctionException catch (e) {
      throw ParentInviteException(
        status: e.status,
        message: _extractErrorMessage(e.details, e.status),
      );
    }
  }

  /// Invokes `generate_parent_setup_invite` — the fallback used when
  /// email delivery is not available. Returns the raw activation code
  /// alongside a pre-formatted Romanian message the admin can copy and
  /// share via WhatsApp, Gmail, SMS, etc.
  ///
  /// Calling this invalidates any previously-issued unconsumed token
  /// for the parent, so the most recently shared code is always the
  /// only working one.
  ///
  /// Throws [ParentInviteException] for any non-2xx response so the UI
  /// can map status → user-facing message; the same convention as
  /// [prepareCreateParent].
  Future<ManualParentInvite> generateManualInvite({
    required bool isAdmin,
    required String parentId,
  }) async {
    if (!isAdmin) throw StateError('Unauthorized role');
    try {
      final response = await _client.functions.invoke(
        'generate_parent_setup_invite',
        body: {'parent_id': parentId},
      );
      final status = response.status;
      final data = response.data;
      if (status != 200) {
        throw ParentInviteException(
          status: status,
          message: _extractErrorMessage(data, status),
        );
      }
      if (data is! Map<String, dynamic>) {
        throw ParentInviteException(
          status: status,
          message: 'Răspuns neașteptat de la server.',
        );
      }
      return ManualParentInvite.fromMap(data);
    } on FunctionException catch (e) {
      throw ParentInviteException(
        status: e.status,
        message: _extractErrorMessage(e.details, e.status),
      );
    }
  }

  static String _extractErrorMessage(dynamic body, int status) {
    if (body is Map) {
      final err = body['error'];
      if (err is String && err.isNotEmpty) return err;
      final msg = body['message'];
      if (msg is String && msg.isNotEmpty) return msg;
    }
    if (body is String && body.isNotEmpty) return body;
    return 'Eroare Edge Function (status $status)';
  }
}
