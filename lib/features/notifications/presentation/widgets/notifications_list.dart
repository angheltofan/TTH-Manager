import 'package:flutter/material.dart';

import '../../domain/app_notification.dart';
import 'notification_tile.dart';

class NotificationsList extends StatelessWidget {
  const NotificationsList({
    super.key,
    required this.notifications,
    required this.onTapNotification,
  });

  final List<AppNotification> notifications;
  final void Function(AppNotification) onTapNotification;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: notifications.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 72, endIndent: 16),
      itemBuilder: (_, i) => NotificationTile(
        notification: notifications[i],
        onTap: () => onTapNotification(notifications[i]),
      ),
    );
  }
}
