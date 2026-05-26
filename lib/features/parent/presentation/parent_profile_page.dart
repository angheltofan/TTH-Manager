import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../auth/providers/auth_providers.dart';
import '../domain/parent_dashboard.dart';
import '../providers/parent_dashboard_providers.dart';
import 'widgets/parent_bottom_nav.dart';
import 'widgets/parent_section_card.dart';

/// Read-only Parent Profile page mounted at `/parent/profile`.
/// Shows identity, linked children, a notification-preferences
/// placeholder, and a logout action.
class ParentProfilePage extends ConsumerWidget {
  const ParentProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final user = ref.watch(currentUserProvider);
    final childrenAsync = ref.watch(parentLinkedChildrenProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          const AppNotificationBell(
            viewAllRoute: '/parent/notifications',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Deconectează-te',
            onPressed: () => _signOut(context, ref),
          ),
        ],
      ),
      bottomNavigationBar: const ParentBottomNav(currentIndex: 1),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: context.mobilePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _IdentityCard(
                  firstName: profile?.firstName ?? '',
                  lastName: profile?.lastName ?? '',
                  email: user?.email,
                ),
                SizedBox(height: context.sectionGap),
                _LinkedChildrenCard(async: childrenAsync),
                SizedBox(height: context.sectionGap),
                const _NotificationPreferencesCard(),
                SizedBox(height: context.sectionGap),
                _LogoutCard(onSignOut: () => _signOut(context, ref)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref.read(authRepositoryProvider).signOut();
    if (context.mounted) context.go('/login');
  }
}

// ── Identity ────────────────────────────────────────────────────────────────

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.firstName,
    required this.lastName,
    required this.email,
  });

  final String firstName;
  final String lastName;
  final String? email;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fullName = '$firstName $lastName'.trim();
    return ParentSectionCard(
      title: 'Date personale',
      icon: Icons.person_rounded,
      iconColor: const Color(0xFF8B5CF6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fullName.isEmpty ? '(fără nume)' : fullName,
            style: theme.textTheme.bodyLarge
                ?.copyWith(fontWeight: FontWeight.w700),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          _MetaRow(
            icon: Icons.alternate_email_rounded,
            label: email == null || email!.isEmpty ? '—' : email!,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.badge_outlined,
                  size: 14, color: theme.colorScheme.outline),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Părinte',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.purple,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Linked children ─────────────────────────────────────────────────────────

class _LinkedChildrenCard extends StatelessWidget {
  const _LinkedChildrenCard({required this.async});
  final AsyncValue<List<ParentDashboardChild>> async;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ParentSectionCard(
      title: 'Copiii tăi',
      icon: Icons.child_care_rounded,
      iconColor: const Color(0xFFEC4899),
      child: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (e, _) => Text(
          'Eroare la încărcare.',
          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.error),
        ),
        data: (children) {
          if (children.isEmpty) {
            return Text(
              'Nu există încă niciun copil asociat.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const Divider(height: 18),
                _ChildRow(child: children[i]),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ChildRow extends StatelessWidget {
  const _ChildRow({required this.child});
  final ParentDashboardChild child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => context.push('/parent/children/${child.id}'),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    child.fullName.isEmpty ? '(fără nume)' : child.fullName,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (child.relationship != null &&
                      child.relationship!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      child.relationship!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ],
                ],
              ),
            ),
            if (child.isPrimary) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Primar',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.purple,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: theme.colorScheme.outline),
          ],
        ),
      ),
    );
  }
}

// ── Notification preferences placeholder ───────────────────────────────────

class _NotificationPreferencesCard extends StatelessWidget {
  const _NotificationPreferencesCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ParentSectionCard(
      title: 'Notificări',
      icon: Icons.notifications_outlined,
      iconColor: const Color(0xFF3B82F6),
      child: Text(
        'Preferințele de notificare vor fi disponibile în curând.',
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.outline),
      ),
    );
  }
}

// ── Logout card ─────────────────────────────────────────────────────────────

class _LogoutCard extends StatelessWidget {
  const _LogoutCard({required this.onSignOut});
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return ParentSectionCard(
      title: 'Sesiune',
      icon: Icons.logout_rounded,
      iconColor: AppColors.error,
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.logout),
          label: const Text('Deconectează-te'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: BorderSide(
              color: AppColors.error.withValues(alpha: 0.4),
            ),
          ),
          onPressed: () => onSignOut(),
        ),
      ),
    );
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────────

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.outline),
        const SizedBox(width: 6),
        Expanded(
          child: Text(label, style: theme.textTheme.bodySmall),
        ),
      ],
    );
  }
}
