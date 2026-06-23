import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
///  • Attachments: image messages render the bitmap inside the bubble
///    above the optional caption; file messages render a 2-line card
///    (icon + name + size, tap-to-open).
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

  /// Image preview width inside the bubble. Capped so portraits don't
  /// dominate the chat; the bubble itself stays under [maxWidth].
  static const _kImageMaxWidth = 240.0;

  Future<void> _openAttachment(BuildContext context) async {
    final url = message.attachmentUrl;
    if (url == null) return;
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Atașamentul nu a putut fi deschis.')),
      );
    }
  }

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

    final hasText = message.hasText;
    final hasAttachment = message.hasAttachment;
    final isImage = message.isImageAttachment;

    // Compose the bubble body. Images live above any text caption;
    // file cards live above any text caption. Time + caption share the
    // existing inline Wrap so the WhatsApp look is preserved for the
    // text-only case.
    final textRow = hasText
        ? Wrap(
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
          )
        : Align(
            alignment: Alignment.bottomRight,
            child: Text(
              formatTime(message.createdAt),
              style: timeStyle,
            ),
          );

    Widget bubbleInner;
    if (hasAttachment && isImage) {
      bubbleInner = Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          _ImagePreview(
            url: message.attachmentUrl!,
            maxWidth: _kImageMaxWidth,
            onTap: () => _openAttachment(context),
          ),
          if (hasText || !hasText) ...[
            SizedBox(height: hasText ? 6 : 4),
            textRow,
          ],
        ],
      );
    } else if (hasAttachment) {
      bubbleInner = Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          _FileCard(
            name: message.attachmentName ?? 'Atașament',
            sizeBytes: message.attachmentSize,
            onMe: isMe,
            onTap: () => _openAttachment(context),
          ),
          SizedBox(height: hasText ? 6 : 4),
          textRow,
        ],
      );
    } else {
      bubbleInner = textRow;
    }

    // Image bubbles use tighter padding so the bitmap kisses the
    // border; text + file bubbles keep the previous WhatsApp padding.
    final bubblePadding = (hasAttachment && isImage && !hasText)
        ? const EdgeInsets.fromLTRB(4, 4, 4, 4)
        : (hasAttachment && isImage)
            ? const EdgeInsets.fromLTRB(4, 4, 4, 6)
            : const EdgeInsets.fromLTRB(10, 6, 10, 5);

    Widget bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: borderRadius,
          border: Border.all(color: borderColor, width: 0.7),
        ),
        padding: bubblePadding,
        child: bubbleInner,
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

// ── Image preview ─────────────────────────────────────────────────────

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({
    required this.url,
    required this.maxWidth,
    required this.onTap,
  });

  final String url;
  final double maxWidth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: maxWidth * 1.4,
          ),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return SizedBox(
                width: maxWidth,
                height: maxWidth * 0.66,
                child: Container(
                  color: theme.colorScheme.surface
                      .withValues(alpha: 0.4),
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            },
            errorBuilder: (_, _, _) => Container(
              width: maxWidth,
              height: 80,
              color: theme.colorScheme.surface.withValues(alpha: 0.4),
              alignment: Alignment.center,
              child: Icon(Icons.broken_image_outlined,
                  color: theme.colorScheme.outline),
            ),
          ),
        ),
      ),
    );
  }
}

// ── File card ─────────────────────────────────────────────────────────

class _FileCard extends StatelessWidget {
  const _FileCard({
    required this.name,
    required this.sizeBytes,
    required this.onMe,
    required this.onTap,
  });

  final String name;
  final int? sizeBytes;
  final bool onMe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = onMe ? Colors.white : theme.colorScheme.onSurface;
    final muted =
        onMe ? Colors.white.withValues(alpha: 0.7) : theme.colorScheme.outline;
    final tile = onMe
        ? Colors.white.withValues(alpha: 0.14)
        : theme.colorScheme.surface.withValues(alpha: 0.55);
    final tileBorder = onMe
        ? Colors.white.withValues(alpha: 0.18)
        : theme.colorScheme.outline.withValues(alpha: 0.25);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 200, maxWidth: 280),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(
            color: tile,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: tileBorder, width: 0.6),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (onMe ? Colors.white : AppColors.purple)
                      .withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.insert_drive_file_outlined,
                  color: onMe ? Colors.white : AppColors.purple,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: fg,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _readableSize(sizeBytes),
                      style: TextStyle(
                        color: muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.download_rounded, color: muted, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  String _readableSize(int? bytes) {
    if (bytes == null || bytes <= 0) return 'Atașament';
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024.0;
    if (kb < 1024) return '${kb.toStringAsFixed(kb < 10 ? 1 : 0)} KB';
    final mb = kb / 1024.0;
    if (mb < 1024) return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)} MB';
    final gb = mb / 1024.0;
    return '${gb.toStringAsFixed(gb < 10 ? 1 : 0)} GB';
  }
}
