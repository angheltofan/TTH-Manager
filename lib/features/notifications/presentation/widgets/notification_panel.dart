import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../domain/app_notification.dart';
import '../../providers/notifications_providers.dart';
import '../notification_url_resolver.dart';
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
    this.viewAllRoute = '/notifications',
  });

  final VoidCallback onClose;
  final bool showHandle;

  /// Route the "Toate notificările" footer link goes to. Defaults to the
  /// staff page; parent screens pass '/parent/notifications'.
  final String viewAllRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final recentAsync = ref.watch(recentNotificationsProvider);
    final unread = ref.watch(unreadNotificationsCountProvider);
    // Parent role detection is read here once per build and threaded
    // into the row click handler so any staff-flavoured `actionUrl`
    // resolves to `/parent` instead of triggering a router redirect.
    final isParent =
        ref.watch(currentProfileProvider).valueOrNull?.isParent ?? false;

    // The dropdown is rendered in two surfaces:
    //   • Desktop / wide → showDialog wraps it in `_NotificationDialog` which
    //     supplies an outer `SingleChildScrollView` (the dropdown shrink-wraps).
    //   • Mobile / narrow → showModalBottomSheet inside a `ConstrainedBox`
    //     (capped at 70 % of screen height). In this mode the dropdown
    //     itself must scroll the list, otherwise the outer `Column` —
    //     previously `mainAxisSize.min` — would overflow the cap and clip
    //     the bottom tiles + the "Toate notificările" footer.
    //
    // The fix: when `showHandle == true` (sheet mode) the list slot
    // becomes a real `Expanded(ListView.separated(...))` and the outer
    // column uses `mainAxisSize.max` so Expanded has a bounded parent.
    // Header + footer stay pinned. Desktop mode keeps the original
    // shrink-wrap Column so the outer SingleChildScrollView still works.
    final inSheet = showHandle;
    return Material(
      type: MaterialType.transparency,
      child: Column(
        mainAxisSize: inSheet ? MainAxisSize.max : MainAxisSize.min,
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
                      unread > 9 ? '9+' : '$unread',
                      style: const TextStyle(
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

          // Notification list area
          _NotificationListArea(
            inSheet: inSheet,
            recentAsync: recentAsync,
            theme: theme,
            onTileTap: (n) async {
              if (!n.isRead) {
                await ref
                    .read(notificationsRepositoryProvider)
                    .markAsRead(notificationId: n.id);
                ref.invalidate(notificationsProvider);
                ref.invalidate(unreadCountFutureProvider);
              }
              final url = n.actionUrl;
              if (url != null && url.isNotEmpty && context.mounted) {
                context.go(resolveNotificationNavUrl(
                  url,
                  isParent: isParent,
                ));
              }
              onClose();
            },
          ),

          // Footer — link to full notifications page
          const Divider(height: 1),
          InkWell(
            onTap: () {
              context.go(viewAllRoute);
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

/// List slot inside [NotificationDropdown].
///
/// In sheet mode it wraps the tiles in `Expanded(ListView.separated)` so
/// the user can reach every notification on iPhone width. In dropdown mode
/// (desktop dialog) it returns a shrink-wrapping `Column` so the parent
/// `SingleChildScrollView` continues to govern overflow.
class _NotificationListArea extends StatelessWidget {
  const _NotificationListArea({
    required this.inSheet,
    required this.recentAsync,
    required this.theme,
    required this.onTileTap,
  });

  final bool inSheet;
  final AsyncValue<List<AppNotification>> recentAsync;
  final ThemeData theme;
  final void Function(AppNotification) onTileTap;

  @override
  Widget build(BuildContext context) {
    Widget content = recentAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'Eroare: $e',
          style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
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
        if (inSheet) {
          // Sheet mode: real ListView scrolls inside Expanded.
          return ListView.separated(
            // Defensive: avoid the Material card painting through the
            // bottom edge of the sheet on devices with thin home indicators.
            padding: EdgeInsets.zero,
            itemCount: list.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, indent: 54, endIndent: 14),
            itemBuilder: (_, i) => _DropdownTile(
              notification: list[i],
              onTap: () => onTileTap(list[i]),
            ),
          );
        }
        // Desktop dropdown: shrink-wrap; parent SingleChildScrollView handles overflow.
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < list.length; i++) ...[
              if (i > 0)
                const Divider(height: 1, indent: 54, endIndent: 14),
              _DropdownTile(
                notification: list[i],
                onTap: () => onTileTap(list[i]),
              ),
            ],
          ],
        );
      },
    );

    return inSheet ? Expanded(child: content) : content;
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