import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../auth/providers/auth_providers.dart';
import '../domain/team_chat_message.dart';
import '../providers/team_chat_providers.dart';

// ── Chat list item model ──────────────────────────────────────────────────────

sealed class _ChatListItem {}

final class _DaySeparatorItem extends _ChatListItem {
  _DaySeparatorItem(this.date);
  final DateTime date;
}

final class _NewMessagesDividerItem extends _ChatListItem {}

final class _MessageItem extends _ChatListItem {
  _MessageItem(
    this.message, {
    required this.isFirstInGroup,
    required this.isLastInGroup,
  });
  final TeamChatMessage message;
  final bool isFirstInGroup;
  final bool isLastInGroup;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _dayLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final d = DateTime(date.year, date.month, date.day);
  if (d == today) return 'Astăzi';
  if (d == yesterday) return 'Ieri';
  return formatDateLong(date);
}

/// Builds the flat list of items for the reversed [ListView.builder].
///
/// [messages] must be sorted newest-first (descending by created_at).
/// [previousLastReadAt] is the [chatLastReadAtProvider] value captured at the
/// moment the page was opened — used to insert a "Mesaje noi" divider between
/// the newest-read and oldest-unread messages without re-reading the provider.
/// [currentUserId] is used to exclude the user's own messages from the
/// unread classification.
List<_ChatListItem> _buildChatItems(
  List<TeamChatMessage> messages, {
  DateTime? previousLastReadAt,
  String? currentUserId,
}) {
  // messages is newest-first (descending from DB).
  // ListView.builder(reverse: true) renders index 0 at the visual bottom,
  // so newest messages naturally appear at the bottom without scrolling.
  final items = <_ChatListItem>[];

  // Pre-scan: find the data-array index of the OLDEST unread message from
  // other users.  With reverse:true that item renders at the TOP of the
  // unread section, just above which we'll place the "Mesaje noi" divider.
  int lastUnreadDataIdx = -1;
  if (previousLastReadAt != null && currentUserId != null) {
    for (int i = 0; i < messages.length; i++) {
      final m = messages[i];
      if (m.senderId != currentUserId &&
          m.createdAt.isAfter(previousLastReadAt)) {
        lastUnreadDataIdx = i; // keep updating → ends at highest index (oldest unread)
      }
    }
    if (kDebugMode && lastUnreadDataIdx >= 0) {
      debugPrint(
          '[Chat] divider after msg idx=$lastUnreadDataIdx id=${messages[lastUnreadDataIdx].id}');
    }
  }

  for (int i = 0; i < messages.length; i++) {
    final msg = messages[i];
    final msgDay =
        DateTime(msg.createdAt.year, msg.createdAt.month, msg.createdAt.day);

    // In the reversed list:
    //   prev (i-1) = newer message → rendered visually BELOW
    //   next (i+1) = older message → rendered visually ABOVE
    final prev = i > 0 ? messages[i - 1] : null; // newer neighbour
    final next =
        i < messages.length - 1 ? messages[i + 1] : null; // older neighbour

    // isFirstInGroup: topmost bubble of a sender group (sender name, full
    // top-corner radius, large top padding before the group).
    // True when the older neighbour is a different sender/day (or no older msg).
    final isFirstInGroup = next == null ||
        next.senderId != msg.senderId ||
        !_isSameDay(next.createdAt, msg.createdAt);

    // isLastInGroup: bottommost bubble of a sender group (full bottom-corner
    // radius). True when the newer neighbour is a different sender/day (or none).
    final isLastInGroup = prev == null ||
        prev.senderId != msg.senderId ||
        !_isSameDay(prev.createdAt, msg.createdAt);

    items.add(_MessageItem(
      msg,
      isFirstInGroup: isFirstInGroup,
      isLastInGroup: isLastInGroup,
    ));

    // Insert day separator after the oldest message of each day.
    final nextMsgDay = next != null
        ? DateTime(
            next.createdAt.year, next.createdAt.month, next.createdAt.day)
        : null;
    if (nextMsgDay == null || nextMsgDay != msgDay) {
      items.add(_DaySeparatorItem(msgDay));
    }

    // Insert "Mesaje noi" divider after the oldest unread message and after
    // any day separator that belongs to it.  With reverse:true, this item
    // renders visually just ABOVE the unread section.
    if (i == lastUnreadDataIdx) {
      items.add(_NewMessagesDividerItem());
    }
  }

  return items;
}

// ── Page ──────────────────────────────────────────────────────────────────────

class TeamChatPage extends ConsumerStatefulWidget {
  const TeamChatPage({super.key});

  @override
  ConsumerState<TeamChatPage> createState() => _TeamChatPageState();
}

class _TeamChatPageState extends ConsumerState<TeamChatPage> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;

  // Holds the lastReadAt value captured the moment this page session opened.
  // Used to determine the "Mesaje noi" divider position and remains stable
  // for the lifetime of this page instance even as new messages arrive.
  DateTime? _previousLastReadAt;
  bool _capturedPreviousLastRead = false;

  @override
  void initState() {
    super.initState();
    // With reverse:true, offset 0 IS the newest messages — no jump needed.
    // Check if messages are already in the provider cache (e.g. pre-loaded by
    // the global realtime listener). If so, handle immediately after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cached = ref.read(teamChatMessagesProvider);
      if (cached.hasValue) _onMessagesAvailable(cached.valueOrNull);
    });
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Scroll ──────────────────────────────────────────────────────────────────

  /// With reverse:true, offset 0 is the visual bottom (newest messages).
  void _scrollToNewest() {
    if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
  }

  // ── Read tracking ─────────────────────────────────────────────────────────

  /// Called whenever the messages provider has data — on initial load and on
  /// every realtime update while this page is mounted.
  ///
  /// First call: captures [_previousLastReadAt] for the "Mesaje noi" divider
  /// BEFORE persisting the new timestamp, so the divider position reflects
  /// what was unread when the user opened the chat.
  /// All calls: marks the newest message as read and scrolls to newest.
  void _onMessagesAvailable(List<TeamChatMessage>? msgs) {
    if (!_capturedPreviousLastRead) {
      // Snapshot the persisted value.  SharedPreferences loads fast so this
      // is almost always the correct persisted timestamp by this point.
      _previousLastReadAt = ref.read(chatLastReadAtProvider);
      _capturedPreviousLastRead = true;
      if (kDebugMode) {
        debugPrint('[Chat] captured previousLastReadAt=$_previousLastReadAt');
      }
      // Rebuild to render the divider at the correct position.
      if (mounted) setState(() {});
    }

    _scrollToNewest();

    // Persist the newest message timestamp so the badge clears immediately.
    final newestTime = (msgs != null && msgs.isNotEmpty)
        ? msgs.first.createdAt // msgs[0] is newest (descending order)
        : DateTime.now();
    ref.read(chatLastReadAtProvider.notifier).markRead(newestTime);
  }

  Future<void> _send() async {
    final body = _msgCtrl.text.trim();
    if (body.isEmpty) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _sending = true);
    try {
      await ref
          .read(teamChatRepositoryProvider)
          .sendMessage(body: body, senderId: user.id);
      _msgCtrl.clear();
      // Scroll to offset 0 = newest messages in reversed list.
      _scrollToNewest();
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare: ${e.message}')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mesajul nu a putut fi trimis.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final profile = ref.read(currentProfileProvider).valueOrNull;
    final isAdmin = profile?.isAdmin ?? false;
    try {
      await ref.read(teamChatRepositoryProvider).softDeleteMessage(
            messageId: messageId,
            currentUserId: user.id,
            isAdmin: isAdmin,
          );
      ref.invalidate(teamChatMessagesProvider);
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eroare la ștergere: ${e.message}')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mesajul nu a putut fi șters.')),
        );
      }
    }
  }

  void _showDeleteMenu(
      BuildContext ctx, Offset globalPosition, String messageId) {
    showMenu<String>(
      context: ctx,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx + 1,
        globalPosition.dy + 1,
      ),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline,
                  size: 18, color: Theme.of(ctx).colorScheme.error),
              const SizedBox(width: 8),
              Text(
                'Șterge mesaj',
                style: TextStyle(color: Theme.of(ctx).colorScheme.error),
              ),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'delete' && mounted) _deleteMessage(messageId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final isStaff =
        profile != null && (profile.isAdmin || profile.isTrainer);

    if (!isStaff) {
      return Scaffold(
        appBar: AppBar(
          leading: const _BackButton(),
          title: const Text('Chat echipă'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Nu ai acces la chatul echipei.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final messagesAsync = ref.watch(teamChatMessagesProvider);
    final currentUserId = ref.watch(currentUserProvider)?.id ?? '';
    final theme = Theme.of(context);

    // Listen for messages updates (initial fetch + realtime).
    ref.listen<AsyncValue<List<TeamChatMessage>>>(teamChatMessagesProvider,
        (prev, next) {
      if (!next.hasValue) return;
      _onMessagesAvailable(next.valueOrNull);
    });

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const _BackButton(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chat echipă',
                style: TextStyle(fontWeight: FontWeight.w700)),
            Text(
              'Grup comun',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Messages area ──────────────────────────────────────────────
            Expanded(
              child: messagesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Eroare: $e'),
                  ),
                ),
                data: (messages) {
                  if (messages.isEmpty) {
                    return Center(
                      child: Text(
                        'Niciun mesaj încă.\nFii primul care scrie!',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: theme.colorScheme.outline),
                      ),
                    );
                  }
                  final items = _buildChatItems(
                    messages,
                    previousLastReadAt: _previousLastReadAt,
                    currentUserId: currentUserId,
                  );

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 600;
                      final maxBubbleWidth =
                          constraints.maxWidth * (isWide ? 0.57 : 0.80);

                      return ListView.builder(
                        controller: _scrollCtrl,
                        reverse: true,
                        padding:
                            const EdgeInsets.fromLTRB(12, 8, 12, 4),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          if (item is _DaySeparatorItem) {
                            return _DaySeparator(
                                label: _dayLabel(item.date));
                          }
                          if (item is _NewMessagesDividerItem) {
                            return const _NewMessagesDivider();
                          }
                          final mi = item as _MessageItem;
                          final msg = mi.message;
                          final isMe = msg.senderId == currentUserId;
                          final canDelete = isMe || profile.isAdmin;

                          return _MessageBubble(
                            message: msg,
                            isMe: isMe,
                            isFirstInGroup: mi.isFirstInGroup,
                            isLastInGroup: mi.isLastInGroup,
                            canDelete: canDelete,
                            maxWidth: maxBubbleWidth,
                            onDeleteRequested: (globalPos) =>
                                _showDeleteMenu(
                                    context, globalPos, msg.id),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),

            const Divider(height: 1),

            // ── Input bar ──────────────────────────────────────────────────
            _ChatInputBar(
              controller: _msgCtrl,
              sending: _sending,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Back button ───────────────────────────────────────────────────────────────

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      tooltip: 'Înapoi',
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/dashboard');
        }
      },
    );
  }
}

// ── "Mesaje noi" divider ─────────────────────────────────────────────────────────────

class _NewMessagesDivider extends StatelessWidget {
  const _NewMessagesDivider();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: AppColors.purple.withValues(alpha: 0.35),
              thickness: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              'Mesaje noi',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.purple,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: AppColors.purple.withValues(alpha: 0.35),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Day separator ─────────────────────────────────────────────────────────────

class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: theme.colorScheme.outline.withValues(alpha: 0.25),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: theme.colorScheme.outline.withValues(alpha: 0.25),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Message bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.isFirstInGroup,
    required this.isLastInGroup,
    required this.canDelete,
    required this.maxWidth,
    required this.onDeleteRequested,
  });

  final TeamChatMessage message;
  final bool isMe;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final bool canDelete;
  final double maxWidth;
  final void Function(Offset globalPosition) onDeleteRequested;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bubbleColor = isMe
        ? AppColors.purple
        : (isDark ? AppColors.surfaceDark : AppColors.bgLight);
    final textColor =
        isMe ? Colors.white : theme.colorScheme.onSurface;
    final metaColor = isMe
        ? Colors.white.withValues(alpha: 0.7)
        : theme.colorScheme.outline;

    // Top padding: larger gap when sender changes, small within same group.
    final topPadding = isFirstInGroup ? 18.0 : 5.0;

    // Border radius: flatten the corner that connects to next bubble in group.
    const r = Radius.circular(16);
    const rSmall = Radius.circular(4);
    final borderRadius = BorderRadius.only(
      topLeft: isMe ? r : (isFirstInGroup ? r : rSmall),
      topRight: isMe ? (isFirstInGroup ? r : rSmall) : r,
      bottomLeft: isMe ? r : (isLastInGroup ? r : rSmall),
      bottomRight: isMe ? (isLastInGroup ? r : rSmall) : r,
    );

    Widget bubble = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            message.body,
            style: TextStyle(color: textColor, fontSize: 14),
          ),
          const SizedBox(height: 3),
          Text(
            formatTime(message.createdAt),
            style: TextStyle(color: metaColor, fontSize: 11),
          ),
        ],
      ),
    );

    // Wrap with gesture detectors for delete action.
    if (canDelete) {
      bubble = GestureDetector(
        onLongPressStart: (details) =>
            onDeleteRequested(details.globalPosition),
        onSecondaryTapUp: (details) =>
            onDeleteRequested(details.globalPosition),
        child: bubble,
      );
    }

    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar column — shown only for others
          if (!isMe) ...[
            SizedBox(
              width: 32,
              child: isFirstInGroup
                  ? _Avatar(initials: message.initials)
                  : null,
            ),
            const SizedBox(width: 6),
          ],

          // Bubble + optional sender name above first in group
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (isFirstInGroup && !isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 3),
                    child: Text(
                      message.senderName,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.purple,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                bubble,
              ],
            ),
          ),

          // Mirror spacer for others' messages.
          if (!isMe) const SizedBox(width: 38),
        ],
      ),
    );
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials});
  final String initials;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: AppColors.purple.withValues(alpha: 0.15),
      child: Text(
        initials,
        style: const TextStyle(
          color: AppColors.purple,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Chat input bar ────────────────────────────────────────────────────────────

class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: CallbackShortcuts(
              bindings: {
                // Desktop: Enter sends; Shift+Enter inserts newline
                const SingleActivator(LogicalKeyboardKey.enter,
                    shift: false): onSend,
              },
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Scrie un mesaj...',
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                        color: theme.colorScheme.outline
                            .withValues(alpha: 0.4)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                        color: theme.colorScheme.outline
                            .withValues(alpha: 0.4)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(
                        color: AppColors.purple, width: 1.5),
                  ),
                ),
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.newline,
              ),
            ),
          ),
          const SizedBox(width: 6),
          _SendButton(sending: sending, onSend: onSend),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.sending, required this.onSend});
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: sending
          ? const SizedBox(
              key: ValueKey('loading'),
              width: 42,
              height: 42,
              child:
                  Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          : IconButton.filled(
              key: const ValueKey('send'),
              style: IconButton.styleFrom(
                  backgroundColor: AppColors.purple,
                  foregroundColor: Colors.white),
              onPressed: onSend,
              icon: const Icon(Icons.send_rounded, size: 18),
            ),
    );
  }
}
