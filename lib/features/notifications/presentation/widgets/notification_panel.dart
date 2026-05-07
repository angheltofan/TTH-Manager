import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../domain/app_notification.dart';
import '../../providers/notifications_providers.dart';
import 'notification_tile.dart';

// ── Compact notification dropdown ─────────────────────────────────────────────
//
// Shows the 5 most recent notifications and a footer link to /notifications.
// Used both in the desktop overlay and as mobile bottom sheet content
// (set showHandle = true for the sheet).

class NotificationDropdown extends ConsumerWidget {
  const NotificationDropdown({
    super.key,
    required this.onClose,
    this.showHandle = false,
  });

  final VoidCallback onClose;
  final bool showHandle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final recentAsync = ref.watch(recentNotificationsProvider);
    final unread = ref.watch(unreadNotificationsCountProvider);

    return Material(
      type: MaterialType.transparency,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle (sheet mode only)
          if (showHandle)
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.muted.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
            child: Row(
              children: [
                Text(
                  'Notificări',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (unread > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      unread > 9 ? '9+' : '$unread',                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Închide',
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Notification list
          recentAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Eroare: $e',
                style:
                    TextStyle(color: theme.colorScheme.error, fontSize: 12),
              ),
            ),
            data: (list) {
              if (list.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 28, horizontal: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.notifications_off_outlined,
                          size: 36, color: AppColors.muted),
                      const SizedBox(height: 8),
                      Text(
                        'Nu există notificări noi.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.muted),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < list.length; i++) ...[
                    if (i > 0)
                      const Divider(
                          height: 1, indent: 54, endIndent: 14),
                    _DropdownTile(
                      notification: list[i],
                      onTap: () async {
                        final n = list[i];
                        if (!n.isRead) {
                          await ref
                              .read(notificationsRepositoryProvider)
                              .markAsRead(n.id);
                          ref.invalidate(notificationsProvider);
                          ref.invalidate(unreadCountFutureProvider);
                        }
                        final url = n.actionUrl;
                        if (url != null &&
                            url.isNotEmpty &&
                            context.mounted) {
                          context.go(url);
                        }
                        onClose();
                      },
                    ),
                  ],
                ],
              );
            },
          ),

          // Footer — link to full notifications page
          const Divider(height: 1),
          InkWell(
            onTap: () {
              context.go('/notifications');
              onClose();
            },
            borderRadius: showHandle
                ? BorderRadius.zero
                : const BorderRadius.vertical(
                    bottom: Radius.circular(12)),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 13),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Toate notificările',
                    style: TextStyle(
                      color: AppColors.purple,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded,
                      size: 14, color: AppColors.purple),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Single tile ───────────────────────────────────────────────────────────────

class _DropdownTile extends StatelessWidget {
  const _DropdownTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final n = notification;
    final (icon, color) = notificationTypeStyle(n.type);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 15, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: n.isRead
                                ? theme.colorScheme.outline
                                : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!n.isRead)
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: const BoxDecoration(
                            color: AppColors.purple,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  if (n.body.isNotEmpty)
                    Text(
                      n.body,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (n.createdAt != null)
                    Text(
                      formatDateTime(n.createdAt!),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        color: theme.colorScheme.outline
                            .withValues(alpha: 0.55),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}