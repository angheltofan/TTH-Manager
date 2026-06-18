import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/app_notification.dart';

class NotificationsRepository {
  const NotificationsRepository(this._client);

  final SupabaseClient _client;

  // ── Server-side expiry filter ─────────────────────────────────────────────
  //
  // Day-specific notifications (e.g. child birthdays) are populated with an
  // `expires_at` timestamp by the `generate_daily_notifications()` RPC.
  // Permanent notifications (e.g. payment-due) leave `expires_at` NULL and
  // remain visible until resolved by other logic.
  //
  // Every read query AND-combines this PostgREST filter so expired rows
  // never reach the bell, the badge, or the full list.
  String _notExpiredFilter() {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    return 'expires_at.is.null,expires_at.gt.$nowIso';
  }

  // ── All notifications (newest first) ─────────────────────────────────────
  //
  // Defense-in-depth: any 'payment'-type notification whose related child is
  // marked as `payment_type = 'free'` is filtered out client-side, in
  // addition to the BEFORE INSERT trigger that blocks such rows from being
  // written. The trigger handles new rows; this filter handles any legacy
  // rows that pre-date the trigger.

  Future<List<AppNotification>> fetchNotifications(String userId) async {
    final data = await _client
        .from('notifications')
        .select('*, children:related_child_id(payment_type)')
        .eq('recipient_id', userId)
        .or(_notExpiredFilter())
        .order('created_at', ascending: false)
        .limit(100);
    return _mapFiltered(data);
  }

  // ── Recent notifications for the bell dropdown ───────────────────────────
  //
  // Returns only:
  //   • unread notifications (regardless of age), OR
  //   • notifications created today (regardless of read status).
  //
  // Both branches are additionally AND-filtered against `expires_at`, so
  // expired birthday rows from previous days never appear.

  Future<List<AppNotification>> fetchRecentNotifications(
      String userId) async {
    final now = DateTime.now();
    final todayStr =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';

    final data = await _client
        .from('notifications')
        .select('*, children:related_child_id(payment_type)')
        .eq('recipient_id', userId)
        .or('is_read.eq.false,created_at.gte.$todayStr')
        .or(_notExpiredFilter())
        .order('created_at', ascending: false)
        .limit(20);

    return _mapFiltered(data);
  }

  /// Casts the PostgREST response, drops `payment`-type notifications whose
  /// related child is a free participant, and maps to [AppNotification].
  List<AppNotification> _mapFiltered(dynamic data) {
    return (data as List)
        .cast<Map<String, dynamic>>()
        .where((row) {
          if (row['type'] != 'payment') return true;
          final child = row['children'];
          if (child is! Map<String, dynamic>) return true;
          return (child['payment_type'] as String? ?? 'paid') != 'free';
        })
        .map(AppNotification.fromMap)
        .toList();
  }

  // ── Unread count ──────────────────────────────────────────────────────────
  //
  // Lightweight count of unread, not-yet-expired notifications. Only the `id`
  // column is selected since we no longer need to filter client-side.

  Future<int> fetchUnreadCount(String userId) async {
    final data = await _client
        .from('notifications')
        .select('id, type, children:related_child_id(payment_type)')
        .eq('recipient_id', userId)
        .eq('is_read', false)
        .or(_notExpiredFilter());
    return (data as List)
        .cast<Map<String, dynamic>>()
        .where((row) {
          if (row['type'] != 'payment') return true;
          final child = row['children'];
          if (child is! Map<String, dynamic>) return true;
          return (child['payment_type'] as String? ?? 'paid') != 'free';
        })
        .length;
  }

  // ── Mark as read ──────────────────────────────────────────────────────────
  //
  // `recipient_id` is derived from the current Supabase auth user — RLS
  // (`notifications_update_own_or_admin`) enforces the same constraint
  // server-side. Filtering in Dart turns a malformed call into a clean
  // 0-row update instead of an opaque RLS error.

  Future<void> markAsRead({required String notificationId}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId)
        .eq('recipient_id', userId);
  }

  Future<void> markAllAsRead() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
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
  //   • Sets `event_date = current_date` and `expires_at = next midnight
  //     Europe/Bucharest`, so the row drops out of the bell + badge after
  //     the day ends without any client-side filtering.
  //   • Uses `NOT EXISTS … AND n.event_date = today` to avoid duplicates.
  //
  // Payment-due rows leave `expires_at` NULL: they remain visible until the
  // payment is resolved by other logic.

  Future<void> generateDailyNotifications() async {
    await _client.rpc('generate_daily_notifications');
  }
}