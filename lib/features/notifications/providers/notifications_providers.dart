import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/notifications_repository.dart';
import '../domain/app_notification.dart';

// ── Repository ────────────────────────────────────────────────────────────────

final notificationsRepositoryProvider =
    Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.watch(supabaseClientProvider));
});

// ── All notifications (newest first, de-duped) ────────────────────────────────

final notificationsProvider =
    FutureProvider<List<AppNotification>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final all = await ref
      .watch(notificationsRepositoryProvider)
      .fetchNotifications(user.id);
  // Defensive dedup by id.
  final seen = <String>{};
  return all.where((n) => seen.add(n.id)).toList();
});

// ── Recent 5 for the bell dropdown ───────────────────────────────────────────
//
// Independent direct DB query (limit 5) — does not wait for the full list.
// Invalidated alongside notificationsProvider after mutations.

final recentNotificationsProvider =
    FutureProvider<List<AppNotification>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final list = await ref
      .watch(notificationsRepositoryProvider)
      .fetchRecentNotifications(user.id);
  final seen = <String>{};
  return list.where((n) => seen.add(n.id)).toList();
});

// ── Unread count (independent lightweight count query) ────────────────────────
//
// Does NOT depend on notificationsProvider. This prevents loading the full
// notification list just to display the badge count in the top bar.

final unreadCountFutureProvider = FutureProvider<int>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return 0;
  return ref
      .watch(notificationsRepositoryProvider)
      .fetchUnreadCount(user.id);
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  return ref.watch(unreadCountFutureProvider).valueOrNull ?? 0;
});

// ── Daily notification generation (once per ProviderScope lifetime) ───────────
//
// NOT auto-disposed: this provider runs exactly once per app session.
// Triggered from DashboardPage.initState() via ref.read(...).
// Never call from build().

final dailyNotificationsGenerationProvider = FutureProvider<void>((ref) async {
  final user = ref.read(currentUserProvider);
  if (user == null) return;
  try {
    await ref
        .read(notificationsRepositoryProvider)
        .generateDailyNotifications();
  } catch (_) {
    // Non-blocking: generation failure must not break the app.
  }
});