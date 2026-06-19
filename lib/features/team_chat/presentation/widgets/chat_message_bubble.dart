import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../domain/team_chat_message.dart';
import 'chat_avatar.dart';

/// Compact bubble — denser than the previous round-balloon style.
///
/// Layout rules:
///  • First-in-group: 10 px top spacing + sender name + avatar.
///  • Intra-group: 2 px top spacing, no sender name, no avatar (reserved
///    leading column stays so bubbles stay aligned with their group).
///  • Inline timestamp at bottom-right of the bubble using a `Wrap`
///    layout — the time docks next to the last text line, falls to a new
///    line only when the message overflows. Mirrors the WhatsApp look.
///  • Outgoing: brand purple, white text.
///  • Incoming: surface colour, 1-px outline (no shadow → flatter, faster).
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
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

  static const _radiusLarge = Radius.circular(14);
  static const _radiusSmall = Radius.circular(4);

  static const _kAvatarLane = 28.0;
  static const _kAvatarGap = 6.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bubbleColor = isMe
        ? AppColors.purple
        : (isDark ? AppColors.surfaceDark : theme.colorScheme.surface);
    final textColor = isMe ? Colors.white : theme.colorScheme.onSurface;
    final metaColor = isMe
        ? Colors.white.withValues(alpha: 0.72)
        : theme.colorScheme.outline;
    final borderColor = isMe
        ? Colors.transparent
        : theme.colorScheme.outline.withValues(alpha: isDark ? 0.18 : 0.22);

    final borderRadius = BorderRadius.only(
      topLeft: isMe ? _radiusLarge : (isFirstInGroup ? _radiusLarge : _radiusSmall),
      topRight: isMe ? (isFirstInGroup ? _radiusLarge : _radiusSmall) : _radiusLarge,
      bottomLeft:
          isMe ? _radiusLarge : (isLastInGroup ? _radiusLarge : _radiusSmall),
      bottomRight:
          isMe ? (isLastInGroup ? _radiusLarge : _radiusSmall) : _radiusLarge,
    );

    final timeStyle = TextStyle(
      color: metaColor,
      fontSize: 10.5,
      height: 1.0,
      fontWeight: FontWeight.w500,
    );

    Widget bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: borderRadius,
          border: Border.all(color: borderColor, width: 0.7),
        ),
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 5),
        child: Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 6,
          children: [
            Text(
              message.body,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                height: 1.32,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                formatTime(message.createdAt),
                style: timeStyle,
              ),
            ),
          ],
        ),
      ),
    );

    if (canDelete) {
      bubble = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPressStart: (d) => onDeleteRequested(d.globalPosition),
        onSecondaryTapUp: (d) => onDeleteRequested(d.globalPosition),
        child: bubble,
      );
    }

    final topPadding = isFirstInGroup ? 10.0 : 2.0;

    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            SizedBox(
              width: _kAvatarLane,
              child: isFirstInGroup
                  ? ChatAvatar(initials: message.initials)
                  : null,
            ),
            const SizedBox(width: _kAvatarGap),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (isFirstInGroup && !isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(
                      message.senderName,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.purple,
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                        height: 1.1,
                      ),
                    ),
                  ),
                bubble,
              ],
            ),
          ),
          // Small breathing room on the opposite side so bubbles never
          // touch the screen edge (mirrors the avatar lane width).
          if (!isMe) const SizedBox(width: 12),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }
}
