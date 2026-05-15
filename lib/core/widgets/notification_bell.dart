import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/providers/auth_providers.dart';
import '../../features/notifications/presentation/widgets/notification_panel.dart';
import '../../features/notifications/providers/notifications_providers.dart';
import '../theme/app_theme.dart';

// ── Notification bell with unread badge ──────────────────────────────────────
//
// Desktop (>= 700 px): showDialog + GlobalKey positioning — avoids
// RenderFollowerLayer transform errors.
// Mobile (< 700 px): modal bottom sheet.
//
// Supply [iconColor] to override the default colour (e.g. white in sidebars).

class AppNotificationBell extends ConsumerStatefulWidget {
  const AppNotificationBell({super.key, this.iconColor});

  final Color? iconColor;

  @override
  ConsumerState<AppNotificationBell> createState() =>
      _AppNotificationBellState();
}

class _AppNotificationBellState extends ConsumerState<AppNotificationBell> {
  final _bellKey = GlobalKey();
  RealtimeChannel? _notifChannel;

  @override
  void initState() {
    super.initState();
    _subscribeToNotifications();
  }

  void _subscribeToNotifications() {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;
    _notifChannel = Supabase.instance.client
        .channel('notif:user:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_id',
            value: userId,
          ),
          callback: (payload) {
            if (kDebugMode) {
              debugPrint('[RT] notif:user:$userId → \${payload.eventType}');
            }
            if (mounted) {
              ref.invalidate(recentNotificationsProvider);
              ref.invalidate(unreadCountFutureProvider);
            }
          },
        )
        .subscribe((status, [error]) {
          if (kDebugMode) {
            debugPrint('[RT] subscribed notif:user:$userId → \$status');
          }
        });
  }

  @override
  void dispose() {
    if (_notifChannel != null) {
      Supabase.instance.client.removeChannel(_notifChannel!);
    }
    super.dispose();
  }

  void _toggle() {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 700) {
      _openDropdown();
    } else {
      _openSheet();
    }
  }

  void _openDropdown() {
    final box =
        _bellKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final topLeft = box.localToGlobal(Offset.zero);
    final btnSize = box.size;
    final screenWidth = MediaQuery.sizeOf(context).width;

    final dropTop = topLeft.dy + btnSize.height + 4;
    final dropRight = screenWidth - topLeft.dx - btnSize.width;

    showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      builder: (ctx) => _NotificationDialog(
        top: dropTop,
        right: dropRight,
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  void _openSheet() {
    final theme = Theme.of(context);
    // Capture screen height before entering the builder so it's not called
    // inside build() of the sheet itself.
    final maxHeight = MediaQuery.sizeOf(context).height * 0.70;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (sheetCtx) => ConstrainedBox(
        // Content-based height: the dropdown Column uses mainAxisSize.min so
        // it naturally sizes to its content. ConstrainedBox only applies a
        // ceiling — the sheet will be short when there are few notifications.
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: NotificationDropdown(
          showHandle: true,
          onClose: () => Navigator.of(sheetCtx).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(unreadNotificationsCountProvider);

    return Stack(
      key: _bellKey,
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, size: 22),
          color: widget.iconColor ?? AppColors.muted,
          tooltip: 'Notificări',
          onPressed: _toggle,
        ),
        if (unread > 0)
          Positioned(
            top: 6,
            right: 6,
            child: IgnorePointer(
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: const TextStyle(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Dropdown dialog wrapper ───────────────────────────────────────────────────
//
// Placed via showDialog (transparent barrier). Uses Stack + Positioned to
// paint the panel at the computed screen coordinates.

class _NotificationDialog extends StatelessWidget {
  const _NotificationDialog({
    required this.top,
    required this.right,
    required this.onClose,
  });

  final double top;
  final double right;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Positioned(
          top: top,
          right: right,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            shadowColor: Colors.black26,
            color: theme.colorScheme.surface,
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 360,
                maxHeight: 420,
              ),
              child: SingleChildScrollView(
                child: SizedBox(
                  width: 360,
                  child: NotificationDropdown(onClose: onClose),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
