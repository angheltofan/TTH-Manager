import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/loading_state.dart';
import '../../auth/providers/auth_providers.dart';
import '../domain/assistant_conversation.dart';
import '../domain/assistant_message.dart';
import '../providers/assistant_providers.dart';
import 'widgets/assistant_conversation_panel.dart';
import 'widgets/assistant_input_bar.dart';
import 'widgets/assistant_message_bubble.dart';
import 'widgets/assistant_quick_prompts.dart';

/// TTH Assistant — staff-only chat page mounted at `/assistant`.
///
/// Layout:
///   • Wide viewports (≥ 900px): the conversation history panel is
///     rendered inline on the left of the chat column.
///   • Narrow viewports: a hamburger button in the header opens the
///     same panel as a drawer.
///
/// The page owns:
///   • initial conversation load (most recent or new)
///   • scroll-to-bottom on load, animate-on-new-message, and a
///     "Mergi jos" button that appears when the user has scrolled up
///   • dialogs for rename / delete confirmation
///
/// All chat / persistence logic lives in [AssistantChatNotifier].
class AssistantPage extends ConsumerStatefulWidget {
  const AssistantPage({super.key});

  @override
  ConsumerState<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends ConsumerState<AssistantPage> {
  final _scrollController = ScrollController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _initStarted = false;
  bool _showJumpButton = false;

  static const _panelBreakpoint = 900.0;
  // With reverse:true, offset 0 IS the visual bottom (newest message).
  // The user is considered "at the bottom" while still within this many
  // pixels of offset 0.
  static const _bottomThreshold = 80.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // With reverse:true, offset 0 is the visual bottom (newest message)
  // and `pos.maxScrollExtent` is the visual top (oldest). "Near bottom"
  // therefore means a small pixel offset.
  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final atBottom =
        _scrollController.position.pixels <= _bottomThreshold;
    if (!atBottom && !_showJumpButton) {
      setState(() => _showJumpButton = true);
    } else if (atBottom && _showJumpButton) {
      setState(() => _showJumpButton = false);
    }
  }

  bool get _userIsAtBottom {
    if (!_scrollController.hasClients) return true;
    return _scrollController.position.pixels <= _bottomThreshold;
  }

  void _jumpToBottom({bool animate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (animate) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(0);
      }
      if (_showJumpButton) setState(() => _showJumpButton = false);
    });
  }

  void _initOnce(String userId) {
    if (_initStarted) return;
    _initStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(assistantChatProvider.notifier).initialize(userId);
    });
  }

  Future<void> _send(String text) async {
    await ref.read(assistantChatProvider.notifier).send(text);
  }

  Future<void> _newConversation() async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;
    await ref.read(assistantChatProvider.notifier).newConversation(userId);
  }

  Future<void> _openConversation(String conversationId) async {
    final scaffold = _scaffoldKey.currentState;
    if (scaffold?.isDrawerOpen == true) Navigator.of(context).pop();
    await ref
        .read(assistantChatProvider.notifier)
        .openConversation(conversationId);
  }

  // ── Rename / delete dialogs ───────────────────────────────────────────────

  Future<void> _rename(AssistantConversation conv) async {
    final controller = TextEditingController(text: conv.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Redenumește conversația'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Titlu nou',
            ),
            onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Anulează'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Salvează'),
            ),
          ],
        );
      },
    );
    if (newTitle == null || newTitle.isEmpty) return;
    await ref
        .read(assistantChatProvider.notifier)
        .renameConversation(conv.id, newTitle);
  }

  Future<void> _delete(AssistantConversation conv) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Șterge conversația'),
          content: Text(
            'Ștergi definitiv "${conv.title}" și toate mesajele ei?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Anulează'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Șterge'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;
    await ref
        .read(assistantChatProvider.notifier)
        .deleteConversation(conv.id, userId);
  }

  Future<void> _toggleFavorite(AssistantConversation conv) async {
    await ref
        .read(assistantChatProvider.notifier)
        .toggleFavorite(conv.id);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final user = ref.watch(currentUserProvider);

    if (profile != null && !profile.isStaff) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Text(
            'Nu ai acces la asistent.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
      );
    }

    if (user != null) _initOnce(user.id);

    final state = ref.watch(assistantChatProvider);

    // No initial-jump bookkeeping. The list is rendered with
    // `ListView.builder(reverse: true)` and newest-first data, so the
    // viewport's default offset 0 IS the visual bottom — the first
    // paint already lands on the latest message. This matches the
    // strategy used by the Team Chat page.
    //
    // The listener below only needs to:
    //   • clear the "Mergi jos" hint when the user switches to another
    //     conversation (the new list naturally re-anchors at bottom);
    //   • on a new message in the *current* conversation, scroll back
    //     to bottom if the user was already there, otherwise show the
    //     "Mergi jos" hint.
    ref.listen<AssistantState>(assistantChatProvider, (prev, next) {
      if (prev?.activeConversationId != next.activeConversationId) {
        if (_showJumpButton) setState(() => _showJumpButton = false);
        return;
      }
      final prevCount = prev?.messages.length ?? 0;
      if (next.messages.length > prevCount) {
        if (_userIsAtBottom) {
          _jumpToBottom(animate: true);
        } else if (!_showJumpButton) {
          setState(() => _showJumpButton = true);
        }
      }
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _panelBreakpoint;
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: theme.scaffoldBackgroundColor,
          drawer: wide
              ? null
              : Drawer(
                  width: 320,
                  child: SafeArea(
                    child: AssistantConversationPanel(
                      conversations: state.conversations,
                      activeConversationId: state.activeConversationId,
                      onOpen: _openConversation,
                      onNewConversation: () {
                        Navigator.of(context).pop();
                        _newConversation();
                      },
                      onRename: _rename,
                      onDelete: _delete,
                      onToggleFavorite: _toggleFavorite,
                      showCloseButton: true,
                      onClose: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
          body: Row(
            children: [
              if (wide)
                _PanelFrame(
                  child: AssistantConversationPanel(
                    conversations: state.conversations,
                    activeConversationId: state.activeConversationId,
                    onOpen: _openConversation,
                    onNewConversation: _newConversation,
                    onRename: _rename,
                    onDelete: _delete,
                    onToggleFavorite: _toggleFavorite,
                  ),
                ),
              Expanded(
                child: _ChatColumn(
                  state: state,
                  scrollController: _scrollController,
                  wide: wide,
                  showJump: _showJumpButton,
                  onJumpToBottom: () => _jumpToBottom(animate: true),
                  onSend: _send,
                  onOpenDrawer: () =>
                      _scaffoldKey.currentState?.openDrawer(),
                  onClearError: () => ref
                      .read(assistantChatProvider.notifier)
                      .clearError(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Panel frame (vertical divider on the right) ─────────────────────────────

class _PanelFrame extends StatelessWidget {
  const _PanelFrame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 280,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: theme.colorScheme.outline.withValues(alpha: 0.15),
            ),
          ),
        ),
        child: child,
      ),
    );
  }
}

// ── Chat column ─────────────────────────────────────────────────────────────

class _ChatColumn extends StatelessWidget {
  const _ChatColumn({
    required this.state,
    required this.scrollController,
    required this.wide,
    required this.showJump,
    required this.onJumpToBottom,
    required this.onSend,
    required this.onOpenDrawer,
    required this.onClearError,
  });

  final AssistantState state;
  final ScrollController scrollController;
  final bool wide;
  final bool showJump;
  final VoidCallback onJumpToBottom;
  final Future<void> Function(String text) onSend;
  final VoidCallback onOpenDrawer;
  final VoidCallback onClearError;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Header(
          conversation: state.activeConversation,
          onOpenDrawer: wide ? null : onOpenDrawer,
        ),
        Expanded(
          child: !state.initialized || state.isLoadingMessages
              ? const Center(child: AppLoading())
              : Stack(
                  children: [
                    state.messages.isEmpty
                        ? _EmptyState(onPick: onSend, disabled: state.isSending)
                        : _MessagesList(
                            controller: scrollController,
                            messages: state.messages,
                            sending: state.isSending,
                          ),
                    if (showJump)
                      Positioned(
                        right: 0,
                        left: 0,
                        bottom: 12,
                        child: Center(
                          child: _JumpToBottomChip(onTap: onJumpToBottom),
                        ),
                      ),
                  ],
                ),
        ),
        if (state.error != null)
          _ErrorBanner(text: state.error!, onDismiss: onClearError),
        AssistantInputBar(
          onSend: onSend,
          busy: state.isSending || !state.initialized,
        ),
      ],
    );
  }
}

// ── Header (back + title + drawer button + new conversation) ───────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.conversation,
    this.onOpenDrawer,
  });

  final AssistantConversation? conversation;

  /// When non-null, the header shows a hamburger button that opens the
  /// conversation drawer (mobile / narrow viewport). Hidden on desktop
  /// because the panel is rendered inline next to the chat column.
  final VoidCallback? onOpenDrawer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = conversation?.title ?? 'TTH Assistant';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          if (onOpenDrawer != null) ...[
            IconButton(
              icon: const Icon(Icons.menu_rounded, size: 18),
              tooltip: 'Conversații',
              onPressed: onOpenDrawer,
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 4),
          ],
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.purple.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.auto_awesome_outlined,
              size: 16,
              color: AppColors.purple,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Asistent operațional pentru staff.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state with quick prompts ──────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onPick, required this.disabled});

  final Future<void> Function(String text) onPick;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bună! Cu ce te ajut?',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Pot răspunde la întrebări despre copii, ateliere, prezențe, '
              'plăți, traineri și statistici. Toate răspunsurile vin din '
              'datele aplicației.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            AssistantQuickPrompts(
              prompts: AssistantQuickPrompts.defaultPrompts,
              onPick: onPick,
              disabled: disabled,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Messages list ───────────────────────────────────────────────────────────

class _MessagesList extends StatelessWidget {
  const _MessagesList({
    required this.controller,
    required this.messages,
    required this.sending,
  });

  final ScrollController controller;
  final List<AssistantMessage> messages;
  final bool sending;

  @override
  Widget build(BuildContext context) {
    // Reverse the list at the view layer only. The provider keeps
    // messages in chronological (ascending) order, which every other
    // consumer expects. With ListView.builder(reverse: true), index 0
    // is the visual bottom — so the data passed in must be newest-first.
    final newestFirst = messages.reversed.toList(growable: false);
    final itemCount = newestFirst.length + (sending ? 1 : 0);
    return ListView.builder(
      controller: controller,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // Typing indicator occupies index 0 (visual bottom, just above
        // the input bar) while a request is in flight.
        if (sending && index == 0) {
          return const AssistantTypingIndicator();
        }
        final msgIndex = sending ? index - 1 : index;
        return AssistantMessageBubble(message: newestFirst[msgIndex]);
      },
    );
  }
}

// ── "Mergi jos" chip ────────────────────────────────────────────────────────

class _JumpToBottomChip extends StatelessWidget {
  const _JumpToBottomChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.purple,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.arrow_downward_rounded,
                  size: 14, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                'Mergi jos',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Error banner ────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.text, required this.onDismiss});
  final String text;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close, size: 16, color: AppColors.error),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
