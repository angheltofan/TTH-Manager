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

  // ── Recent 5 for the bell dropdown (direct DB query) ─────────────────────

  Future<List<AppNotification>> fetchRecentNotifications(
      String userId) async {
    final data = await _client
        .from('notifications')
        .select()
        .eq('recipient_id', userId)
        .order('created_at', ascending: false)
        .limit(5);
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(AppNotification.fromMap)
        .toList();
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

  // ── Birthday notifications ────────────────────────────────────────────────
  //
  // Idempotent: one notification per (recipient_id, related_child_id) per day.
  // Not called from the app UI — invoke from a server function or admin tool.

  Future<void> insertBirthdayNotifications() async {
    final now = DateTime.now();
    // ISO-8601 date string: YYYY-MM-DD — used as gte filter (start of today).
    final todayStr =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';

    // 1. Children whose birthday falls today (month + day match).
    final allChildren = await _client
        .from('children')
        .select('id, first_name, last_name, birth_date')
        .eq('is_active', true);

    final birthdayChildren = (allChildren as List)
        .cast<Map<String, dynamic>>()
        .where((c) {
          final dt = DateTime.tryParse((c['birth_date'] as String?) ?? '');
          return dt != null && dt.month == now.month && dt.day == now.day;
        })
        .toList();

    if (birthdayChildren.isEmpty) return;

    // 2. All admin recipients.
    final admins = await _client
        .from('profiles')
        .select('id')
        .eq('role', 'admin');

    final adminIds = (admins as List)
        .cast<Map<String, dynamic>>()
        .map((a) => a['id'] as String)
        .toList();

    if (adminIds.isEmpty) return;

    // 3. Already-sent today — dedup key: recipient_id|related_child_id
    final existing = await _client
        .from('notifications')
        .select('recipient_id, related_child_id')
        .eq('type', 'info')
        .not('related_child_id', 'is', null)
        .gte('created_at', todayStr);

    final sent = (existing as List)
        .cast<Map<String, dynamic>>()
        .map((e) => '${e['recipient_id']}|${e['related_child_id']}')
        .toSet();

    // 4. Insert only missing pairs.
    final toInsert = <Map<String, dynamic>>[];
    for (final adminId in adminIds) {
      for (final child in birthdayChildren) {
        final key = '$adminId|${child['id']}';
        if (!sent.contains(key)) {
          final first = child['first_name'] as String? ?? '';
          final last = child['last_name'] as String? ?? '';
          toInsert.add({
            'title': 'Zi de nastere',
            'body': '$first $last isi serbeaza ziua astazi.',
            'type': 'info',
            'recipient_id': adminId,
            'related_child_id': child['id'],
          });
        }
      }
    }

    if (toInsert.isNotEmpty) {
      await _client.from('notifications').insert(toInsert);
    }
  }
}