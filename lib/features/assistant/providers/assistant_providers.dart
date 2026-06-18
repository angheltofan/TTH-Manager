import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../data/assistant_repository.dart';
import '../domain/assistant_conversation.dart';
import '../domain/assistant_message.dart';

final assistantRepositoryProvider = Provider<AssistantRepository>((ref) {
  return AssistantRepository(ref.watch(supabaseClientProvider));
});

/// Aggregate state for the Assistant page. Holds:
///   • the user's full conversation list (sorted newest-first)
///   • the active conversation id and its messages
///   • transient flags for loading / sending / error
class AssistantState {
  const AssistantState({
    this.conversations = const [],
    this.activeConversationId,
    this.messages = const [],
    this.isLoadingConversations = false,
    this.isLoadingMessages = false,
    this.isSending = false,
    this.initialized = false,
    this.error,
  });

  final List<AssistantConversation> conversations;
  final String? activeConversationId;
  final List<AssistantMessage> messages;
  final bool isLoadingConversations;
  final bool isLoadingMessages;
  final bool isSending;
  final bool initialized;
  final String? error;

  AssistantConversation? get activeConversation {
    if (activeConversationId == null) return null;
    for (final c in conversations) {
      if (c.id == activeConversationId) return c;
    }
    return null;
  }

  AssistantState copyWith({
    List<AssistantConversation>? conversations,
    String? activeConversationId,
    List<AssistantMessage>? messages,
    bool? isLoadingConversations,
    bool? isLoadingMessages,
    bool? isSending,
    bool? initialized,
    String? error,
    bool clearError = false,
    bool clearActiveConversationId = false,
  }) {
    return AssistantState(
      conversations: conversations ?? this.conversations,
      activeConversationId: clearActiveConversationId
          ? null
          : (activeConversationId ?? this.activeConversationId),
      messages: messages ?? this.messages,
      isLoadingConversations:
          isLoadingConversations ?? this.isLoadingConversations,
      isLoadingMessages: isLoadingMessages ?? this.isLoadingMessages,
      isSending: isSending ?? this.isSending,
      initialized: initialized ?? this.initialized,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class AssistantChatNotifier extends StateNotifier<AssistantState> {
  AssistantChatNotifier(this._repo) : super(const AssistantState());

  final AssistantRepository _repo;

  /// Loads (or creates) the user's most-recent conversation, its
  /// message history, and the full conversation list. Idempotent —
  /// subsequent calls early-return.
  Future<void> initialize(String userId) async {
    if (state.initialized) return;
    state = state.copyWith(
      isLoadingConversations: true,
      isLoadingMessages: true,
      clearError: true,
    );
    try {
      // 1. Conversation list. RLS already scopes to this user.
      final convs = await _repo.fetchConversations();
      // 2. Pick the active conversation — the most recent one, or
      //    create an empty one if the user has none.
      AssistantConversation active;
      var conversations = convs;
      if (convs.isEmpty) {
        active = await _repo.createConversation(userId);
        conversations = [active];
      } else {
        active = convs.first;
      }
      // 3. Messages for the active conversation.
      final msgs = await _repo.fetchMessages(active.id);
      state = AssistantState(
        conversations: conversations,
        activeConversationId: active.id,
        messages: msgs,
        initialized: true,
      );
    } catch (_) {
      state = state.copyWith(
        isLoadingConversations: false,
        isLoadingMessages: false,
        initialized: true,
        error: 'Nu am putut încărca asistentul.',
      );
    }
  }

  /// Switch the active conversation and reload its messages. No-op if
  /// the conversation is already active.
  Future<void> openConversation(String conversationId) async {
    if (state.activeConversationId == conversationId) return;
    state = state.copyWith(
      activeConversationId: conversationId,
      messages: const [],
      isLoadingMessages: true,
      clearError: true,
    );
    try {
      final msgs = await _repo.fetchMessages(conversationId);
      state = state.copyWith(messages: msgs, isLoadingMessages: false);
    } catch (_) {
      state = state.copyWith(
        isLoadingMessages: false,
        error: 'Nu am putut încărca conversația.',
      );
    }
  }

  /// Creates a fresh conversation. If the current one is still empty
  /// (no messages), the existing empty conversation is reused so the
  /// user can't pile up duplicates by hammering "Conversație nouă".
  Future<void> newConversation(String userId) async {
    if (state.messages.isEmpty && state.activeConversationId != null) {
      // Already on an empty conversation; nothing to create.
      return;
    }
    state = state.copyWith(clearError: true);
    try {
      final conv = await _repo.createConversation(userId);
      state = state.copyWith(
        conversations: [conv, ...state.conversations],
        activeConversationId: conv.id,
        messages: const [],
      );
    } catch (_) {
      state = state.copyWith(error: 'Nu am putut crea o conversație nouă.');
    }
  }

  /// Sends [text] as a user message. The user turn is persisted before
  /// the Edge Function call so a network failure doesn't lose the input.
  /// After the assistant reply lands, the conversation list is reordered
  /// and (if the title is still the default) auto-renamed.
  Future<void> send(String text) async {
    final conversationId = state.activeConversationId;
    if (conversationId == null) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isSending) return;

    AssistantMessage userMsg;
    try {
      userMsg = await _repo.insertMessage(
        conversationId: conversationId,
        role: AssistantRole.user,
        content: trimmed,
      );
    } catch (_) {
      state = state.copyWith(error: 'Mesajul nu a putut fi salvat.');
      return;
    }
    final wasEmpty = state.messages.isEmpty;
    final pending = [...state.messages, userMsg];
    state = state.copyWith(
      messages: pending,
      isSending: true,
      clearError: true,
    );

    try {
      final reply = await _repo.sendMessage(_recentHistory(pending));
      final assistantMsg = await _repo.insertMessage(
        conversationId: conversationId,
        role: AssistantRole.assistant,
        content: reply.reply,
        sources: reply.sources,
      );
      state = state.copyWith(
        messages: [...pending, assistantMsg],
        isSending: false,
      );
      // Auto-rename when this was the first user turn.
      if (wasEmpty) {
        await _maybeAutoRename(conversationId, trimmed);
      }
      // Refresh the list so last_message_at order is reflected.
      await _refreshConversationsList();
    } on AssistantException catch (e) {
      state = state.copyWith(isSending: false, error: _humanize(e));
    } catch (_) {
      state = state.copyWith(
        isSending: false,
        error: 'A apărut o eroare. Încearcă din nou.',
      );
    }
  }

  Future<void> renameActive(String newTitle) async {
    final id = state.activeConversationId;
    if (id == null) return;
    await renameConversation(id, newTitle);
  }

  Future<void> renameConversation(String id, String newTitle) async {
    try {
      final updated = await _repo.renameConversation(id, newTitle);
      state = state.copyWith(
        conversations: _replaceConversation(updated),
      );
    } catch (_) {
      state = state.copyWith(
        error: 'Conversația nu a putut fi redenumită.',
      );
    }
  }

  Future<void> toggleFavorite(String id) async {
    final current = _findConversation(id);
    if (current == null) return;
    try {
      final updated = await _repo.setFavorite(
        id,
        isFavorite: !current.isFavorite,
      );
      state = state.copyWith(
        conversations: _replaceConversation(updated),
      );
    } catch (_) {
      state = state.copyWith(
        error: 'Nu am putut actualiza favoritele.',
      );
    }
  }

  Future<void> deleteConversation(String id, String userId) async {
    try {
      await _repo.deleteConversation(id);
      final remaining =
          state.conversations.where((c) => c.id != id).toList(growable: false);
      // If we just deleted the active one, switch to the next available
      // (or create a fresh empty conversation when nothing remains).
      if (state.activeConversationId == id) {
        if (remaining.isEmpty) {
          final fresh = await _repo.createConversation(userId);
          state = state.copyWith(
            conversations: [fresh],
            activeConversationId: fresh.id,
            messages: const [],
          );
        } else {
          final next = remaining.first;
          state = state.copyWith(
            conversations: remaining,
            activeConversationId: next.id,
            messages: const [],
            isLoadingMessages: true,
          );
          final msgs = await _repo.fetchMessages(next.id);
          state = state.copyWith(messages: msgs, isLoadingMessages: false);
        }
      } else {
        state = state.copyWith(conversations: remaining);
      }
    } catch (_) {
      state = state.copyWith(
        error: 'Conversația nu a putut fi ștearsă.',
      );
    }
  }

  void clearError() {
    if (state.error == null) return;
    state = state.copyWith(clearError: true);
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  AssistantConversation? _findConversation(String id) {
    for (final c in state.conversations) {
      if (c.id == id) return c;
    }
    return null;
  }

  List<AssistantConversation> _replaceConversation(
    AssistantConversation updated,
  ) {
    return state.conversations
        .map((c) => c.id == updated.id ? updated : c)
        .toList(growable: false);
  }

  Future<void> _refreshConversationsList() async {
    try {
      final convs = await _repo.fetchConversations();
      state = state.copyWith(conversations: convs);
    } catch (_) {
      // Silent — the list is just visual; old order survives.
    }
  }

  Future<void> _maybeAutoRename(
    String conversationId,
    String firstUserText,
  ) async {
    final current = _findConversation(conversationId);
    if (current == null) return;
    if (current.title != 'Conversație nouă' && current.title.trim().isNotEmpty) {
      return;
    }
    final title = generateConversationTitle(firstUserText);
    if (title == current.title) return;
    try {
      final updated = await _repo.renameConversation(conversationId, title);
      state = state.copyWith(
        conversations: _replaceConversation(updated),
      );
    } catch (_) {
      // Title is cosmetic; don't surface a failure here.
    }
  }

  /// Edge Function receives at most 30 messages to keep prompts bounded
  /// — same cap the function enforces server-side as defense in depth.
  List<AssistantMessage> _recentHistory(List<AssistantMessage> all) {
    if (all.length <= 30) return all;
    return all.sublist(all.length - 30);
  }

  static String _humanize(AssistantException e) {
    switch (e.status) {
      case 401:
        return 'Sesiune expirată. Reautentificați-vă.';
      case 403:
        return 'Nu ai permisiunea de a folosi asistentul.';
      case 429:
        return 'Prea multe cereri într-un interval scurt. Încearcă din nou peste puțin timp.';
      case 502:
      case 503:
        return 'Asistentul este temporar indisponibil. Încearcă din nou.';
      default:
        return e.message;
    }
  }
}

// ── Local title generator ───────────────────────────────────────────────────

/// Builds a short conversation title from the user's first message.
/// Local, deterministic, no extra OpenAI call.
String generateConversationTitle(String firstMessage) {
  var t = firstMessage.trim();
  if (t.isEmpty) return 'Conversație nouă';
  // Strip leading/trailing punctuation that adds noise to a heading.
  t = t.replaceAll(RegExp(r'^[\s\?\!\.,;:]+|[\s\?\!\.,;:]+$'), '').trim();
  if (t.isEmpty) return 'Conversație nouă';
  // Capitalise the first character.
  t = t[0].toUpperCase() + t.substring(1);
  // Clamp around 50 chars at a word boundary; trailing ellipsis when cut.
  const maxLen = 50;
  if (t.length > maxLen) {
    var cut = t.substring(0, maxLen);
    final lastSpace = cut.lastIndexOf(' ');
    if (lastSpace > 30) cut = cut.substring(0, lastSpace);
    t = '$cut…';
  }
  return t;
}

final assistantChatProvider =
    StateNotifierProvider<AssistantChatNotifier, AssistantState>((ref) {
  return AssistantChatNotifier(ref.watch(assistantRepositoryProvider));
});
