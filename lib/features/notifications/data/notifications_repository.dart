import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/app_notification.dart';

class NotificationsRepository {
  const NotificationsRepository(this._client);

  final SupabaseClient _client;

  // ── All notifications (newest first) ─────────────────────────────────────

  Future<List<AppNotification>> fetchNotifications(String userId) async {
    final data = await _client
        .from('notifications')
        .select()
        .eq('recipient_id', userId)
        .order('created_at', ascending: false)
        .limit(100);
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(AppNotification.fromMap)
        .toList();
  }

  // ── Recent notifications for the bell dropdown ───────────────────────────
  //
  // Returns only:
  //   • unread notifications (regardless of age), OR
  //   • notifications created today (regardless of read status).
  //
  // Birthday or other info notifications from previous days will NOT appear
  // here once they are read. They remain visible on the full /notifications
  // page.

  Future<List<AppNotification>> fetchRecentNotifications(
      String userId) async {
    final now = DateTime.now();
    // Local "today" start — YYYY-MM-DD.  PostgREST compares created_at
    // (timestamptz) against this date string using >= operator.
    final todayStr =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';

    final data = await _client
        .from('notifications')
        .select()
        .eq('recipient_id', userId)
        .or('is_read.eq.false,created_at.gte.$todayStr')
        .order('created_at', ascending: false)
        .limit(20);

    final all = (data as List)
        .cast<Map<String, dynamic>>()
        .map(AppNotification.fromMap)
        .toList();

    // Birthday notifications are only relevant on the day they were created.
    // Filter out any birthday notification whose creation date is before today,
    // even if it is unread (e.g. was generated yesterday and never opened).
    final today = DateTime(now.year, now.month, now.day);
    return all.where((n) {
      final isBirthday = n.title.toLowerCase().startsWith('zi de na');
      if (isBirthday) {
        final createdAt = n.createdAt;
        if (createdAt == null) return false;
        final createdLocal = createdAt.toLocal();
        final createdDay = DateTime(
            createdLocal.year, createdLocal.month, createdLocal.day);
        return !createdDay.isBefore(today);
      }
      return true;
    }).toList();
  }

  // ── Unread count ──────────────────────────────────────────────────────────

  Future<int> fetchUnreadCount(String userId) async {
    final data = await _client
        .from('notifications')
        .select('id')
        .eq('recipient_id', userId)
        .eq('is_read', false);
    return (data as List).length;
  }

  // ── Mark as read ──────────────────────────────────────────────────────────

  Future<void> markAsRead(String notificationId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  Future<void> markAllAsRead(String userId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('recipient_id', userId)
        .eq('is_read', false);
  }

  // ── Daily notification generation (RPC, once per session) ──────────────────
  //
  // Calls the server-side `generate_daily_notifications()` SQL function which:
  //   • Inserts child birthday notifications for all admin/trainer recipients
  //   • Avoids duplicates with NOT EXISTS checks
  //
  // SQL to create the function (run once in Supabase SQL editor):
  //
  //   CREATE OR REPLACE FUNCTION generate_daily_notifications()
  //   RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
  //   DECLARE today date := current_date; BEGIN
  //     INSERT INTO notifications (title, body, type, recipient_id, related_child_id)
  //     SELECT
  //       'Zi de naştere',
  //       c.first_name || ' ' || c.last_name || ' îşi serbează ziua astăzi!',
  //       'info', p.id, c.id
  //     FROM children c CROSS JOIN profiles p
  //     WHERE c.is_active = true
  //       AND EXTRACT(MONTH FROM c.birth_date) = EXTRACT(MONTH FROM today)
  //       AND EXTRACT(DAY   FROM c.birth_date) = EXTRACT(DAY   FROM today)
  //       AND p.role IN ('admin', 'trainer')
  //       AND NOT EXISTS (
  //         SELECT 1 FROM notifications n
  //         WHERE n.recipient_id = p.id
  //           AND n.related_child_id = c.id
  //           AND n.type = 'info'
  //           AND DATE(n.created_at) = today
  //       );
  //   END; $$;

  Future<void> generateDailyNotifications() async {
    await _client.rpc('generate_daily_notifications');
  }
}