import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import '../../features/auth/providers/auth_providers.dart';

/// Branded full-screen startup splash shown ONLY during the very first app
/// launch, until the bootstrap signals required for clean first paint have
/// resolved:
///   • Supabase auth state has emitted at least once (logged-in vs not).
///   • If logged in, the [currentProfileProvider] has resolved (role known
///     so the router redirect can finalise the destination).
///   • A minimum visible time has elapsed to prevent a flash on fast paths.
///
/// Once "ready" is reached the flag becomes sticky — subsequent rebuilds
/// always render the routed app and the splash never reappears on
/// navigation, tab switches, or after-startup auth-state rotations.
class StartupGate extends ConsumerStatefulWidget {
  const StartupGate({super.key, required this.child});

  final Widget child;

  /// Minimum visible duration of the splash. Keeps the brand visible long
  /// enough to avoid a single-frame flash when the session is already
  /// cached and the dashboard data is hot.
  static const Duration minVisible = Duration(milliseconds: 700);

  @override
  ConsumerState<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends ConsumerState<StartupGate> {
  bool _minTimeElapsed = false;
  bool _appReady = false;

  @override
  void initState() {
    super.initState();
    Timer(StartupGate.minVisible, () {
      if (mounted) setState(() => _minTimeElapsed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_appReady) {
      final authState = ref.watch(authStateProvider);
      final authReady = authState.hasValue || authState.hasError;

      final user = ref.watch(currentUserProvider);

      bool profileReady = true;
      if (user != null) {
        final profileAsync = ref.watch(currentProfileProvider);
        profileReady = profileAsync.hasValue || profileAsync.hasError;
      }

      if (authReady && profileReady && _minTimeElapsed) {
        _appReady = true;
      }
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: _appReady
          ? KeyedSubtree(
              key: const ValueKey('startup-gate-app'),
              child: widget.child,
            )
          : const _BrandedSplash(key: ValueKey('startup-gate-splash')),
    );
  }
}

class _BrandedSplash extends StatefulWidget {
  const _BrandedSplash({super.key});

  @override
  State<_BrandedSplash> createState() => _BrandedSplashState();
}

class _BrandedSplashState extends State<_BrandedSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.shortestSide < 480;
    final logoSize = isCompact ? 88.0 : 104.0;
    final titleStyle = (isCompact
            ? theme.textTheme.titleLarge
            : theme.textTheme.headlineSmall)
        ?.copyWith(
      fontWeight: FontWeight.w700,
      color: cs.onSurface,
      letterSpacing: -0.4,
    );

    return Material(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/app_logo.png',
                        width: logoSize,
                        height: logoSize,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'TTH Manager',
                        textAlign: TextAlign.center,
                        style: titleStyle,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tales & Tech HUB',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.62),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 36),
                      const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.purple,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Se încarcă datele centrului...',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
