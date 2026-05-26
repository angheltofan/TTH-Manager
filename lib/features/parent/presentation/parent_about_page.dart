import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../auth/providers/auth_providers.dart';
import 'widgets/parent_bottom_nav.dart';
import 'widgets/parent_quick_contact_card.dart';
import 'widgets/parent_section_card.dart';

/// Static "About Tales & Tech" page mounted at `/parent/about`.
class ParentAboutPage extends ConsumerWidget {
  const ParentAboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Despre'),
        actions: [
          const AppNotificationBell(
            viewAllRoute: '/parent/notifications',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Deconectează-te',
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      bottomNavigationBar: const ParentBottomNav(currentIndex: 2),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: context.mobilePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: const [
                _AboutCard(),
                SizedBox(height: 12),
                _WorkshopTypesCard(),
                SizedBox(height: 12),
                _ProgramLocationCard(),
                SizedBox(height: 12),
                ParentQuickContactCard(title: 'Contactează-ne'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── About description ──────────────────────────────────────────────────────

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ParentSectionCard(
      title: 'Despre Tales & Tech HUB',
      icon: Icons.auto_stories_rounded,
      iconColor: const Color(0xFF8B5CF6),
      child: Text(
        'Tales & Tech HUB este un spațiu dedicat copiilor pasionați de '
        'tehnologie. Organizăm ateliere săptămânale unde copiii învață '
        'să construiască, să programeze și să-și dezvolte gândirea '
        'logică prin proiecte practice.',
        style: theme.textTheme.bodyMedium,
      ),
    );
  }
}

// ── Workshop types ─────────────────────────────────────────────────────────

class _WorkshopTypesCard extends StatelessWidget {
  const _WorkshopTypesCard();

  static const _types = <String>[
    'Robotică',
    'Programare',
    'LEGO',
    'AI / tehnologie',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ParentSectionCard(
      title: 'Tipuri de ateliere',
      icon: Icons.school_rounded,
      iconColor: const Color(0xFF3B82F6),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _types
            .map(
              (label) => Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.purple.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.purple.withValues(alpha: 0.30),
                  ),
                ),
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.purple,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ── Program & location placeholders ────────────────────────────────────────

class _ProgramLocationCard extends StatelessWidget {
  const _ProgramLocationCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ParentSectionCard(
      title: 'Program și locație',
      icon: Icons.place_outlined,
      iconColor: const Color(0xFF10B981),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PlaceholderRow(
            icon: Icons.schedule_outlined,
            label: 'Programul detaliat va fi disponibil în curând.',
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 10),
          _PlaceholderRow(
            icon: Icons.location_on_outlined,
            label: 'Adresa va fi disponibilă în curând.',
            color: theme.colorScheme.outline,
          ),
        ],
      ),
    );
  }
}

class _PlaceholderRow extends StatelessWidget {
  const _PlaceholderRow({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
