import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../auth/providers/auth_providers.dart';
import 'widgets/settings_widgets.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final profileAsync = ref.watch(currentProfileProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Page title
          Text(
            'Setări',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Gestionați preferințele și contul dvs.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 28),

          // ── Aspect ──
          SettingsGroup(
            title: 'Aspect',
            icon: Icons.palette_outlined,
            iconColor: AppColors.purple,
            children: [
              SettingsTile(
                icon: Icons.brightness_6_outlined,
                title: 'Temă',
                subtitle: switch (themeMode) {
                  ThemeMode.light => 'Luminoasă',
                  ThemeMode.dark => 'Întunecată',
                  ThemeMode.system => 'Urmează sistemul',
                },
                trailing: ThemeSegmentedButton(
                  themeMode: themeMode,
                  onChanged: (mode) =>
                      ref.read(themeModeProvider.notifier).state = mode,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Cont ──
          SettingsGroup(
            title: 'Cont',
            icon: Icons.person_outlined,
            iconColor: AppColors.info,
            children: [
              profileAsync.when(
                data: (profile) => SettingsTile(
                  icon: Icons.badge_outlined,
                  title: profile?.fullName ?? 'Utilizator',
                  subtitle: profile != null
                      ? (profile.isAdmin ? 'Administrator' : 'Trainer')
                      : 'Rol necunoscut',
                ),
                loading: () => const SettingsTile(
                  icon: Icons.badge_outlined,
                  title: '...',
                  subtitle: '',
                ),
                error: (_, _) => const SettingsTile(
                  icon: Icons.badge_outlined,
                  title: 'Utilizator',
                  subtitle: '',
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Securitate ──
          SettingsGroup(
            title: 'Securitate',
            icon: Icons.security_outlined,
            iconColor: AppColors.success,
            children: [
              SettingsTile(
                icon: Icons.lock_outline_rounded,
                title: 'Schimbare parolă',
                subtitle: 'Actualizați parola contului',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Funcție disponibilă în curând.'),
                    ),
                  );
                },
                showChevron: true,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Despre aplicație ──
          SettingsGroup(
            title: 'Despre aplicație',
            icon: Icons.info_outline_rounded,
            iconColor: AppColors.warning,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/images/app_logo.png',
                        width: 64,
                        height: 64,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TTH Manager',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tales & Tech HUB',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'v0.1.0',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Deconectare ──
          SettingsLogoutTile(
            onTap: () async {
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) context.go('/login');
            },
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
