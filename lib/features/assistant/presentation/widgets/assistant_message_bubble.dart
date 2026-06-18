import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/assistant_message.dart';

/// Single chat bubble.
///
///   • User messages render as plain selectable text on a brand-purple
///     background, right-aligned.
///   • Assistant messages render as Markdown (bold, lists, paragraphs,
///     line breaks) on a surface card, left-aligned. A small "Date
///     analizate: ..." footer appears under the bubble when the Edge
///     Function returned non-empty `sources`.
///
/// Style decisions: typography (`bodyMedium`, line-height 1.35),
/// bubble radius and outline come from the same primitives the staff
/// chat uses; no oversized blocks.
class AssistantMessageBubble extends StatelessWidget {
  const AssistantMessageBubble({super.key, required this.message});

  final AssistantMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.role == AssistantRole.user;
    final align = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bgColor = isUser
        ? AppColors.purple
        : (theme.cardTheme.color ?? theme.colorScheme.surface);
    final fgColor = isUser ? Colors.white : theme.colorScheme.onSurface;
    final borderColor = isUser
        ? AppColors.purple
        : theme.colorScheme.outline.withValues(alpha: 0.3);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: align,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(isUser ? 14 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 14),
                ),
                border: Border.all(color: borderColor),
              ),
              child: isUser
                  ? SelectableText(
                      message.content,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: fgColor,
                        height: 1.35,
                      ),
                    )
                  : _AssistantMarkdown(
                      content: message.content,
                      theme: theme,
                    ),
            ),
          ),
          if (!isUser && message.sources.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 6, right: 6),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: _SourcesFooter(sources: message.sources),
              ),
            ),
        ],
      ),
    );
  }
}

class _AssistantMarkdown extends StatelessWidget {
  const _AssistantMarkdown({required this.content, required this.theme});

  final String content;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final base = theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface,
          height: 1.4,
        ) ??
        const TextStyle();
    final styleSheet = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: base,
      strong: base.copyWith(fontWeight: FontWeight.w700),
      em: base.copyWith(fontStyle: FontStyle.italic),
      h1: theme.textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
      h2: theme.textTheme.titleSmall
          ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.1),
      h3: base.copyWith(fontWeight: FontWeight.w700),
      listBullet: base,
      blockSpacing: 8,
      listIndent: 16,
      code: base.copyWith(
        fontFamily: 'monospace',
        fontSize: (base.fontSize ?? 14) - 1,
        backgroundColor:
            theme.colorScheme.outline.withValues(alpha: 0.08),
      ),
      codeblockPadding: const EdgeInsets.all(8),
      codeblockDecoration: BoxDecoration(
        color: theme.colorScheme.outline.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
      ),
    );
    return MarkdownBody(
      data: content,
      selectable: true,
      styleSheet: styleSheet,
      shrinkWrap: true,
    );
  }
}

class _SourcesFooter extends StatelessWidget {
  const _SourcesFooter({required this.sources});

  final List<String> sources;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        Icon(
          Icons.dataset_outlined,
          size: 13,
          color: theme.colorScheme.outline,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'Date analizate: ${sources.join(", ")}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
              fontSize: 11,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Compact "thinking" indicator shown while the Edge Function is
/// processing the user's last message.
class AssistantTypingIndicator extends StatelessWidget {
  const AssistantTypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(14),
          ),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.purple,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Asistentul caută în baza de date…',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
