import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../auth/providers/auth_providers.dart';
import '../../notifications/providers/notifications_providers.dart';

/// Realtime subscription on `notifications` for the currently-signed-in
/// parent user. Counterpart to the staff-side `appRealtimeProvider` which
/// gates on `isAdmin || isTrainer`; this gates on `isParent`.
///
/// RLS (`notifications_select_recipient_self`) restricts the Realtime
/// stream to rows where `recipient_id = auth.uid()`, so no client-side
/// filter is required.
///
/// AutoDispose so the channel is torn down whenever no parent-side widget
/// is watching (sign-out, navigation to a sub-page that drops the bottom
/// nav, app backgrounded long enough for the autoDispose grace period).
final parentNotificationsRealtimeProvider =
    Provider.autoDispose<void>((ref) {
  final user = ref.watch(currentUserProvider);
  final profile = ref.watch(currentProfileProvider).valueOrNull;
  if (user == null || profile == null || !profile.isParent) return;

  final client = ref.watch(supabaseClientProvider);
  if (kDebugMode) {
    debugPrint('[RT] parent_notifications: subscribing for ${user.id}');
  }

  final channel = client
      .channel('parent_notifications:${user.id}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'notifications',
        callback: (payload) {
          if (kDebugMode) {
            debugPrint(
              '[RT] parent_notifications → ${payload.eventType}',
            );
          }
          ref.invalidate(notificationsProvider);
          ref.invalidate(recentNotificationsProvider);
          ref.invalidate(unreadCountFutureProvider);
        },
      )
      .subscribe();

  ref.onDispose(() {
    if (kDebugMode) {
      debugPrint('[RT] parent_notifications: removing channel');
    }
    client.removeChannel(channel);
  });
});
