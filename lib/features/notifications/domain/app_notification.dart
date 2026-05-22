/// Domain model for a row in `public.notifications`.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.type,
    required this.recipientId,
    this.isRead = false,
    this.relatedChildId,
    this.relatedWorkshopId,
    this.createdAt,
    this.actionUrl,
    this.priority,
    this.expiresAt,
    this.eventDate,
  });

  final String id;
  final String title;
  final String body;

  /// `info` | `payment` | `attendance` | `material` | `schedule`
  final String? type;

  final String recipientId;
  final bool isRead;
  final String? relatedChildId;
  final String? relatedWorkshopId;
  final DateTime? createdAt;
  final String? actionUrl;

  /// `high` | `normal` | `low` | null
  final String? priority;

  /// Moment after which the notification is no longer shown in the bell or
  /// badge. NULL means the notification never expires.
  final DateTime? expiresAt;

  /// Logical date the notification refers to (birthday date, workshop date).
  /// Used server-side by the generator's duplicate guard.
  final DateTime? eventDate;

  bool get isHighPriority => priority == 'high';

  factory AppNotification.fromMap(Map<String, dynamic> map) => AppNotification(
        id: map['id'] as String,
        title: map['title'] as String? ?? '',
        body: map['body'] as String? ?? '',
        type: map['type'] as String?,
        recipientId: map['recipient_id'] as String? ?? '',
        isRead: map['is_read'] as bool? ?? false,
        relatedChildId: map['related_child_id'] as String?,
        relatedWorkshopId: map['related_workshop_id'] as String?,
        createdAt: map['created_at'] != null
            ? DateTime.tryParse(map['created_at'] as String)
            : null,
        actionUrl: map['action_url'] as String?,
        priority: map['priority'] as String?,
        expiresAt: map['expires_at'] != null
            ? DateTime.tryParse(map['expires_at'] as String)
            : null,
        eventDate: map['event_date'] != null
            ? DateTime.tryParse(map['event_date'] as String)
            : null,
      );
}
