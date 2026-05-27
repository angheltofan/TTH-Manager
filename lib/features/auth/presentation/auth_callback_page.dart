import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
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

  // Debug-only diagnostic snapshot. Populated by [_process] and rendered
  // by [build] only when [kDebugMode] is true; release builds never see
  // this state.
  Map<String, String>? _debugInfo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _process());
  }

  Future<void> _process() async {
    final client = Supabase.instance.client;
    final uri = Uri.base;

    // Snapshot the URL state BEFORE any side effect — getSessionFromUrl
    // strips the fragment via history.replaceState on success.
    final originalUriStr = uri.toString();
    final originalFragment = uri.fragment;
    final originalQuery = uri.query;

    // Parse fragment params BEFORE calling getSessionFromUrl.
    final fragmentParams = uri.fragment.isNotEmpty
        ? Uri.splitQueryString(uri.fragment)
        : const <String, String>{};
    final queryParams = uri.queryParameters;

    final authType = fragmentParams['type']; // 'invite' | 'recovery' | 'magiclink' | null
    final hasFragmentTokens = fragmentParams.containsKey('access_token') ||
        fragmentParams.containsKey('refresh_token');
    final hasCode = queryParams.containsKey('code');
    final urlHadAuthParams = hasFragmentTokens || hasCode;

    // GoTrue redirects expired or already-consumed links to the callback
    // with the error info attached — sometimes in the fragment, sometimes
    // in the query string. Capture either form.
    final goTrueError =
        fragmentParams['error'] ?? queryParams['error'];
    final goTrueErrorCode =
        fragmentParams['error_code'] ?? queryParams['error_code'];
    final goTrueErrorDescription =
        fragmentParams['error_description'] ?? queryParams['error_description'];

    final beforeSession = client.auth.currentSession;
    String? authErrorMsg; // captured for the on-screen debug panel

    if (kDebugMode) {
      debugPrint('[AuthCallback] uri              = ${uri.toString()}');
      debugPrint('[AuthCallback] uri.fragment     = "${uri.fragment}"');
      debugPrint('[AuthCallback] uri.queryParams  = $queryParams');
      debugPrint('[AuthCallback] authType         = $authType');
      debugPrint('[AuthCallback] hasFragmentTokens=$hasFragmentTokens hasCode=$hasCode');
      debugPrint('[AuthCallback] goTrueError      = $goTrueError');
      debugPrint('[AuthCallback] goTrueErrorCode  = $goTrueErrorCode');
      debugPrint('[AuthCallback] goTrueErrorDesc  = $goTrueErrorDescription');
      debugPrint('[AuthCallback] session BEFORE   = ${beforeSession?.user.id ?? 'null'}');
    }

    // Builds the on-screen debug snapshot from everything we know so
    // far. Called from every terminal state (error or just-before-nav)
    // so the panel always reflects the actual processing path.
    Map<String, String> snapshot(Session? after) => {
          'Uri.base.toString()': originalUriStr,
          'Uri.base.fragment':
              originalFragment.isEmpty ? '<empty>' : originalFragment,
          'Uri.base.query':
              originalQuery.isEmpty ? '<empty>' : originalQuery,
          'hasFragmentTokens': hasFragmentTokens.toString(),
          'hasCode': hasCode.toString(),
          'authType': authType ?? '<null>',
          'goTrueError': goTrueError ?? '<none>',
          'goTrueErrorCode': goTrueErrorCode ?? '<none>',
          'goTrueErrorDesc': goTrueErrorDescription ?? '<none>',
          'session BEFORE': beforeSession == null
              ? 'null'
              : 'user=${beforeSession.user.id}',
          'session AFTER': after == null ? 'null' : 'user=${after.user.id}',
          'getSessionFromUrl error': authErrorMsg ?? '<none>',
        };

    // If GoTrue already told us the link is bad, don't even bother
    // calling getSessionFromUrl — go straight to the error UI.
    if (goTrueError != null) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Linkul de autentificare a expirat sau a fost deja folosit. '
            'Cere o invitație nouă.';
        _debugInfo = snapshot(beforeSession);
      });
      return;
    }

    // Always call getSessionFromUrl with the original URI before any
    // navigation, so the token in the fragment is consumed exactly once.
    if (urlHadAuthParams) {
      try {
        await client.auth.getSessionFromUrl(uri);
      } on AuthException catch (e) {
        authErrorMsg =
            'AuthException statusCode=${e.statusCode} code=${e.code} '
            'message=${e.message}';
        if (kDebugMode) {
          debugPrint('[AuthCallback] $authErrorMsg');
        }
      } catch (e) {
        authErrorMsg = 'Error: $e';
        if (kDebugMode) {
          debugPrint('[AuthCallback] getSessionFromUrl threw: $e');
        }
      }
    } else if (kDebugMode) {
      debugPrint(
        '[AuthCallback] No access_token / refresh_token / code in URL — '
        'skipping getSessionFromUrl.',
      );
    }

    final afterSession = client.auth.currentSession;

    if (kDebugMode) {
      debugPrint(
        '[AuthCallback] session AFTER    = ${afterSession?.user.id ?? 'null'}',
      );
    }

    if (!mounted) return;

    if (afterSession == null) {
      // Two sub-cases, same user-facing copy: the URL did carry tokens
      // (so this was a real auth attempt that failed — most likely the
      // link expired or was used) OR the URL had no auth payload at all
      // (someone deep-linked to /auth/callback by accident). In neither
      // case do we want to tell the user to "log in manually" — for a
      // freshly invited parent there's no password to log in with.
      setState(() {
        _errorMessage =
            'Linkul de autentificare a expirat sau a fost deja folosit. '
            'Cere o invitație nouă.';
        _debugInfo = snapshot(afterSession);
      });
      return;
    }

    // Success path: capture the snapshot too so the panel renders the
    // good state briefly before we navigate (helps verify production
    // setup).
    setState(() => _debugInfo = snapshot(afterSession));

    // Invite or password-recovery sessions land on the set-password
    // flow first. SetPasswordPage handles role-based routing after a
    // successful password update.
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
    final main = _errorMessage == null
        ? <Widget>[
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
        : <Widget>[
            Icon(
              Icons.error_outline,
              size: 40,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => context.go('/login'),
              child: const Text('Înapoi'),
            ),
          ];

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...main,
                  if (kDebugMode && _debugInfo != null) ...[
                    const SizedBox(height: 32),
                    _DebugPanel(info: _debugInfo!),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// On-screen diagnostic panel rendered only when [kDebugMode] is true.
/// Provides the same information as the `[AuthCallback]` debug logs in a
/// form that survives a Vercel deploy (the browser console isn't always
/// accessible during a remote test).
class _DebugPanel extends StatelessWidget {
  const _DebugPanel({required this.info});
  final Map<String, String> info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Debug (kDebugMode)',
            style: theme.textTheme.labelMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final entry in info.entries) ...[
            _DebugRow(label: entry.key, value: entry.value),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

class _DebugRow extends StatelessWidget {
  const _DebugRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SelectableText.rich(
      TextSpan(
        style: theme.textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          fontSize: 11,
        ),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }
}
