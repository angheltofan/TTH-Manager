import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/assistant_conversation.dart';

/// One row in the conversation history panel.
class AssistantConversationItem extends StatelessWidget {
  const AssistantConversationItem({
    super.key,
    required this.conversation,
    required this.isActive,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
    required this.onToggleFavorite,
  });

  final AssistantConversation conversation;
  final bool isActive;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fav = conversation.isFavorite;
    final activeBg = AppColors.purple.withValues(alpha: 0.10);
    final borderColor = isActive
        ? AppColors.purple.withValues(alpha: 0.35)
        : Colors.transparent;

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Icon(
              fav ? Icons.star_rounded : Icons.chat_bubble_outline_rounded,
              size: 14,
              color: fav
                  ? AppColors.warning
                  : theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    conversation.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive
                          ? AppColors.purple
                          : theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatRelative(conversation.activityAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            _Overflow(
              isFavorite: fav,
              onRename: onRename,
              onToggleFavorite: onToggleFavorite,
              onDelete: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  static String _formatRelative(DateTime ts) {
    final now = DateTime.now();
    final diff = now.difference(ts);
    if (diff.inMinutes < 1) return 'acum';
    if (diff.inMinutes < 60) return 'acum ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'acum ${diff.inHours} h';
    if (diff.inDays < 7) return 'acum ${diff.inDays} z';
    // dd.MM.yyyy
    final d = ts.day.toString().padLeft(2, '0');
    final m = ts.month.toString().padLeft(2, '0');
    return '$d.$m.${ts.year}';
  }
}

class _Overflow extends StatelessWidget {
  const _Overflow({
    required this.isFavorite,
    required this.onRename,
    required this.onToggleFavorite,
    required this.onDelete,
  });

  final bool isFavorite;
  final VoidCallback onRename;
  final VoidCallback onToggleFavorite;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Opțiuni',
      icon: const Icon(Icons.more_horiz, size: 18),
      padding: EdgeInsets.zero,
      onSelected: (v) {
        switch (v) {
          case 'rename':
            onRename();
            break;
          case 'fav':
            onToggleFavorite();
            break;
          case 'delete':
            onDelete();
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          value: 'rename',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 16),
              SizedBox(width: 8),
              Text('Redenumește'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'fav',
          child: Row(
            children: [
              Icon(
                isFavorite ? Icons.star_border_rounded : Icons.star_rounded,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(isFavorite ? 'Scoate de la favorite' : 'Adaugă la favorite'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded,
                  size: 16, color: AppColors.error),
              SizedBox(width: 8),
              Text('Șterge', style: TextStyle(color: AppColors.error)),
            ],
          ),
        ),
      ],
    );
  }
}
