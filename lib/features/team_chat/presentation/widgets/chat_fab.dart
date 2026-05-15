import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../providers/team_chat_providers.dart';

/// Floating chat button shown on the Dashboard.
/// Only rendered for admin/trainer — caller is responsible for gating.
class ChatFab extends ConsumerWidget {
  const ChatFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(teamChatUnreadCountProvider);
    final hasUnread = unreadCount > 0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        FloatingActionButton(
          heroTag: 'chat_fab',
          backgroundColor: AppColors.purple,
          foregroundColor: Colors.white,
          tooltip: 'Chat echipă',
          onPressed: () => context.go('/team-chat'),
          child: const Icon(Icons.chat_rounded),
        ),
        if (hasUnread)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
