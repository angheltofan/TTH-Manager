import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/auth_providers.dart';
import '../domain/app_notification.dart';
import '../providers/notifications_providers.dart';
import 'notification_url_resolver.dart';
import 'widgets/notifications_empty_state.dart';
import 'widgets/notifications_list.dart';

// ── Filter enum ───────────────────────────────────────────────────────────────

enum _Filter { all, unread, read }

extension _FilterLabel on _Filter {
  String get label => switch (this) {
        _Filter.all => 'Toate',
        _Filter.unread => 'Necitite',
        _Filter.read => 'Citite',
      };
}

// ── Page ──────────────────────────────────────────────────────────────────────

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  _Filter _filter = _Filter.all;

  List<AppNotification> _applyFilter(List<AppNotification> all) {
    final seen = <String>{};
    final deduped = all.where((n) => seen.add(n.id)).toList();
    return switch (_filter) {
      _Filter.all => deduped,
      _Filter.unread => deduped.where((n) => !n.isRead).toList(),
      _Filter.read => deduped.where((n) => n.isRead).toList(),
    };
  }

  Future<void> _markAllAsRead() async {
    await ref.read(notificationsRepositoryProvider).markAllAsRead();
    ref.invalidate(notificationsProvider);
    ref.invalidate(recentNotificationsProvider);
    ref.invalidate(unreadCountFutureProvider);
  }

  Future<void> _markOneAsRead(AppNotification n) async {
    if (n.isRead) return;
    await ref
        .read(notificationsRepositoryProvider)
        .markAsRead(notificationId: n.id);
    ref.invalidate(notificationsProvider);
    ref.invalidate(recentNotificationsProvider);
    ref.invalidate(unreadCountFutureProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(notificationsProvider);
    // Role-aware fallback for the back-arrow and parent-safe URL
    // rewriting on row clicks. Parents are bounced from staff routes
    // by the router; resolving to `/parent` up-front avoids the flash.
    final isParent =
        ref.watch(currentProfileProvider).valueOrNull?.isParent ?? false;
    final homeRoute = isParent ? '/parent' : '/dashboard';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth =
              constraints.maxWidth > 800 ? 800.0 : constraints.maxWidth;

          return Center(
            child: SizedBox(
              width: maxWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Page header ───────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 24, 16, 0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded),
                          onPressed: () => context.canPop()
                              ? context.pop()
                              : context.go(homeRoute),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Notificări',
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        async.whenOrNull(
                              data: (list) {
                                final hasUnread =
                                    list.any((n) => !n.isRead);
                                if (!hasUnread) return null;
                                return TextButton.icon(
                                  onPressed: _markAllAsRead,
                                  icon: const Icon(Icons.done_all_rounded,
                                      size: 16),
                                  label: const Text(
                                    'Marchează toate ca citite',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                );
                              },
                            ) ??
                            const SizedBox.shrink(),
                      ],
                    ),
                  ),

                  // ── Filter chips ──────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: Wrap(
                      spacing: 8,
                      children: _Filter.values
                          .map(
                            (f) => ChoiceChip(
                              label: Text(f.label),
                              selected: _filter == f,
                              onSelected: (_) =>
                                  setState(() => _filter = f),
                              visualDensity: VisualDensity.compact,
                            ),
                          )
                          .toList(),
                    ),
                  ),

                  const Divider(height: 1),

                  // ── Content ───────────────────────────────────────────────
                  Expanded(
                    child: async.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      error: (e, _) => Center(
                        child: Text(
                          'Eroare: $e',
                          style: TextStyle(
                              color: theme.colorScheme.error),
                        ),
                      ),
                      data: (allList) {
                        final list = _applyFilter(allList);
                        if (list.isEmpty) {
                          return const NotificationsEmptyState();
                        }
                        return NotificationsList(
                          notifications: list,
                          onTapNotification: (n) async {
                            await _markOneAsRead(n);
                            final url = n.actionUrl;
                            if (url != null &&
                                url.isNotEmpty &&
                                context.mounted) {
                              context.go(resolveNotificationNavUrl(
                                url,
                                isParent: isParent,
                              ));
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
