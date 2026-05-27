import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/auth_providers.dart';

/// Landing page for Supabase auth redirects (invite, password recovery,
/// magic link). Mounted at `/auth/callback`.
///
/// Flow:
///   1. If the inbound URL carries auth params (`access_token=...` in the
///      fragment, or `code=...` in the query), call `getSessionFromUrl`
///      to convert them into a Supabase session. `Supabase.initialize()`
///      also attempts this automatically on web — calling it explicitly
///      here covers race conditions and any platform quirks.
///   2. Wait for the session to be available, then read the user's
///      profile and route to the role-appropriate home (`/parent` or
///      `/dashboard`).
///   3. If anything fails, fall back to `/login` with a brief on-screen
///      message so the user isn't left staring at a spinner.
class AuthCallbackPage extends ConsumerStatefulWidget {
  const AuthCallbackPage({super.key});

  @override
  ConsumerState<AuthCallbackPage> createState() => _AuthCallbackPageState();
}

class _AuthCallbackPageState extends ConsumerState<AuthCallbackPage> {
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _process());
  }

  Future<void> _process() async {
    final client = Supabase.instance.client;
    final uri = Uri.base;

    // Parse fragment params BEFORE calling getSessionFromUrl — that call
    // strips the fragment from the browser URL on success.
    final fragmentParams = uri.fragment.isNotEmpty
        ? Uri.splitQueryString(uri.fragment)
        : const <String, String>{};
    final authType = fragmentParams['type']; // 'invite' | 'recovery' | 'magiclink' | null
    final hasFragmentTokens =
        fragmentParams.containsKey('access_token') ||
            fragmentParams.containsKey('refresh_token');
    final hasCode = uri.queryParameters.containsKey('code');

    if (hasFragmentTokens || hasCode) {
      try {
        await client.auth.getSessionFromUrl(uri);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[AuthCallback] getSessionFromUrl failed: $e');
        }
      }
    }

    if (!mounted) return;

    final session = client.auth.currentSession;
    if (session == null) {
      setState(() => _errorMessage =
          'Sesiunea nu a putut fi creată. Te rugăm să te autentifici manual.');
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      context.go('/login');
      return;
    }

    // Invite or password-recovery sessions land on the set-password
    // flow first. The SetPasswordPage handles the role-based routing
    // after a successful password update.
    if (authType == 'invite' || authType == 'recovery') {
      context.go('/set-password');
      return;
    }

    // Otherwise (magic link, post-OAuth, direct callback entry with an
    // existing session) route by role.
    try {
      ref.invalidate(currentProfileProvider);
      final profile = await ref.read(currentProfileProvider.future);
      if (!mounted) return;
      if (profile?.isParent == true) {
        context.go('/parent');
      } else {
        context.go('/dashboard');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AuthCallback] profile load failed: $e');
      }
      if (!mounted) return;
      // Default destination; router will re-route parents once profile loads.
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _errorMessage == null
                ? [
                    const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Se finalizează autentificarea…',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ]
                : [
                    Icon(
                      Icons.error_outline,
                      size: 32,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ],
          ),
        ),
      ),
    );
  }
}
