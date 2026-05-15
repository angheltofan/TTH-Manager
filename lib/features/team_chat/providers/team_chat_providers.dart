import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/team_chat_repository.dart';
import '../domain/team_chat_message.dart';

// ── Repository ────────────────────────────────────────────────────────────────

final teamChatRepositoryProvider = Provider<TeamChatRepository>((ref) {
  return TeamChatRepository(ref.watch(supabaseClientProvider));
});

// ── Messages list ─────────────────────────────────────────────────────────────

final teamChatMessagesProvider =
    FutureProvider<List<TeamChatMessage>>((ref) {
  if (kDebugMode) debugPrint('[Chat] teamChatMessagesProvider: fetching');
  return ref.watch(teamChatRepositoryProvider).fetchMessages();
});

// ── Last-read timestamp (persisted via SharedPreferences per user) ────────────

class _ChatLastReadAtNotifier extends StateNotifier<DateTime?> {
  _ChatLastReadAtNotifier(this._userId) : super(null) {
    if (_userId != null) _load();
  }

  final String? _userId;
  static const _keyPrefix = 'team_chat_last_read_at_';

  String? get _key =>
      _userId != null ? '$_keyPrefix$_userId' : null;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_key!);
    if (mounted && ms != null) {
      final dt = DateTime.fromMillisecondsSinceEpoch(ms);
      if (kDebugMode) debugPrint('[Chat] loaded lastReadAt=$dt');
      state = dt;
    }
  }

  /// Updates state immediately (badge clears at once) and persists to prefs.
  Future<void> markRead(DateTime time) async {
    state = time;
    if (kDebugMode) debugPrint('[Chat] saved lastReadAt=$time');
    final key = _key;
    if (key == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, time.millisecondsSinceEpoch);
  }
}

/// Persisted last-read timestamp for the current user.
/// Keyed by user ID so switching accounts works correctly.
/// State starts as [null] while SharedPreferences loads, then updates once the
/// async read completes (fast — typically < 5 ms after first access).
final chatLastReadAtProvider =
    StateNotifierProvider<_ChatLastReadAtNotifier, DateTime?>((ref) {
  final userId = ref.watch(currentUserProvider)?.id;
  return _ChatLastReadAtNotifier(userId);
});

// ── Unread count ──────────────────────────────────────────────────────────────

/// Messages from other users newer than [chatLastReadAtProvider].
/// Deleted and own messages are excluded.
final teamChatUnreadCountProvider = Provider<int>((ref) {
  final messages = ref.watch(teamChatMessagesProvider).valueOrNull;
  final lastReadAt = ref.watch(chatLastReadAtProvider);
  final currentUserId = ref.watch(currentUserProvider)?.id;
  if (messages == null || messages.isEmpty) return 0;
  if (currentUserId == null) return 0;
  final count = messages.where((m) {
    if (m.senderId == currentUserId) return false; // own messages never unread
    if (lastReadAt == null) return true;            // never read → all unread
    return m.createdAt.isAfter(lastReadAt);
  }).length;
  if (kDebugMode) debugPrint('[Chat] unread count: $count');
  return count;
});

// ── Global realtime listener ──────────────────────────────────────────────────

/// Subscribes to `public.team_chat_messages` while any staff user is logged in.
/// Watched by [AppShell] so it lives as long as the authenticated shell is
/// mounted. AutoDispose removes the channel on logout (shell unmounts).
final teamChatRealtimeProvider = Provider.autoDispose<void>((ref) {
  final profile = ref.watch(currentProfileProvider).valueOrNull;
  if (profile == null || (!profile.isAdmin && !profile.isTrainer)) return;

  final client = ref.watch(supabaseClientProvider);
  if (kDebugMode) debugPrint('[RT] team_chat: subscribing global channel');

  final channel = client
      .channel('global_team_chat:messages')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'team_chat_messages',
        callback: (payload) {
          if (kDebugMode) {
            debugPrint('[RT] team_chat global → ${payload.eventType}');
          }
          ref.invalidate(teamChatMessagesProvider);
        },
      )
      .subscribe();

  ref.onDispose(() {
    if (kDebugMode) debugPrint('[RT] team_chat: removing global channel');
    client.removeChannel(channel);
  });
});

