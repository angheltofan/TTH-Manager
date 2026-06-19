import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/date_utils.dart';
import '../../domain/team_chat_message.dart';
import 'chat_date_separator.dart';
import 'chat_message_bubble.dart';
import 'chat_new_messages_divider.dart';

// ── Chat list item model ──────────────────────────────────────────────────────

sealed class ChatListItem {}

final class _DaySeparatorItem extends ChatListItem {
  _DaySeparatorItem(this.date);
  final DateTime date;
}

final class _NewMessagesDividerItem extends ChatListItem {}

final class _MessageItem extends ChatListItem {
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

String dayLabel(DateTime date) {
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
/// Semantics identical to the previous in-page builder so realtime
/// behaviour, "Mesaje noi" placement and grouping are unchanged.
List<ChatListItem> buildChatItems(
  List<TeamChatMessage> messages, {
  DateTime? previousLastReadAt,
  String? currentUserId,
}) {
  final items = <ChatListItem>[];

  int lastUnreadDataIdx = -1;
  if (previousLastReadAt != null && currentUserId != null) {
    for (int i = 0; i < messages.length; i++) {
      final m = messages[i];
      if (m.senderId != currentUserId &&
          m.createdAt.isAfter(previousLastReadAt)) {
        lastUnreadDataIdx = i;
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

    final prev = i > 0 ? messages[i - 1] : null;
    final next = i < messages.length - 1 ? messages[i + 1] : null;

    final isFirstInGroup = next == null ||
        next.senderId != msg.senderId ||
        !_isSameDay(next.createdAt, msg.createdAt);

    final isLastInGroup = prev == null ||
        prev.senderId != msg.senderId ||
        !_isSameDay(prev.createdAt, msg.createdAt);

    items.add(_MessageItem(
      msg,
      isFirstInGroup: isFirstInGroup,
      isLastInGroup: isLastInGroup,
    ));

    final nextMsgDay = next != null
        ? DateTime(
            next.createdAt.year, next.createdAt.month, next.createdAt.day)
        : null;
    if (nextMsgDay == null || nextMsgDay != msgDay) {
      items.add(_DaySeparatorItem(msgDay));
    }

    if (i == lastUnreadDataIdx) {
      items.add(_NewMessagesDividerItem());
    }
  }

  return items;
}

// ── List view ────────────────────────────────────────────────────────────────

class ChatMessagesList extends StatelessWidget {
  const ChatMessagesList({
    super.key,
    required this.items,
    required this.currentUserId,
    required this.canDeleteForAdmin,
    required this.scrollController,
    required this.onDeleteRequested,
  });

  final List<ChatListItem> items;
  final String currentUserId;
  final bool canDeleteForAdmin;
  final ScrollController scrollController;
  final void Function(Offset globalPosition, String messageId)
      onDeleteRequested;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Tighter, screen-aware bubble cap. Desktop / tablet stop scaling
        // at 520 px so messages never become awkward wide ribbons.
        final double maxBubbleWidth;
        if (width >= 900) {
          maxBubbleWidth = 520;
        } else if (width >= 600) {
          maxBubbleWidth = width * 0.62;
        } else {
          maxBubbleWidth = width * 0.82;
        }

        return ListView.builder(
          controller: scrollController,
          reverse: true,
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            if (item is _DaySeparatorItem) {
              return ChatDateSeparator(label: dayLabel(item.date));
            }
            if (item is _NewMessagesDividerItem) {
              return const ChatNewMessagesDivider();
            }
            final mi = item as _MessageItem;
            final msg = mi.message;
            final isMe = msg.senderId == currentUserId;
            final canDelete = isMe || canDeleteForAdmin;

            return ChatMessageBubble(
              message: msg,
              isMe: isMe,
              isFirstInGroup: mi.isFirstInGroup,
              isLastInGroup: mi.isLastInGroup,
              canDelete: canDelete,
              maxWidth: maxBubbleWidth,
              onDeleteRequested: (pos) => onDeleteRequested(pos, msg.id),
            );
          },
        );
      },
    );
  }
}
