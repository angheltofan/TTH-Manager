import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Custom parent password-setup page. Mounted at `/parent-setup`.
///
/// Replaces the previous Supabase invite-OTP flow, which proved
/// unreliable in production: corporate email scanners pre-fetch the
/// `{{ .ConfirmationURL }}` and consume the underlying Supabase
/// `confirmation_token`, which also invalidates the `{{ .Token }}`
/// OTP shown in the email body — both forms share one credential.
///
/// New flow:
///   1. Admin creates parent → Edge Function `create_parent_and_link_child`
///      mints a 256-bit random token, stores `sha256(token||pepper)` in
///      `parent_setup_tokens`, sends an email through Resend with
///      `https://…/parent-setup?token=<raw>&email=<encoded>`.
///   2. Parent clicks link → this page opens with the token + email in
///      the URL query. Parent enters new password.
///   3. We POST `{email, token, password}` to Edge Function
///      `complete_parent_setup`. The function verifies the token hash,
///      sets the password via `auth.admin.updateUserById`, marks the
///      token consumed.
///   4. On success we route the parent to `/login` so they sign in
///      with the password they just chose (the function does NOT mint
///      a session — parent logs in normally).
class ParentSetupPage extends ConsumerStatefulWidget {
  const ParentSetupPage({super.key});

  @override
  ConsumerState<ParentSetupPage> createState() => _ParentSetupPageState();
}

class _ParentSetupPageState extends ConsumerState<ParentSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _saving = false;
  bool _obscurePwd = true;
  bool _obscureConfirm = true;

  // The raw setup token, read from the URL query at initState. Kept
  // out of the form on purpose — it's a 256-bit opaque value, no user
  // would ever type it. If the URL didn't carry one, we surface a
  // dedicated error UI instead of asking the parent to paste 43 chars.
  String? _token;

  // True when the URL had neither `?token=` nor any usable state. The
  // page then renders a short "link invalid" screen with a back CTA.
  bool _missingToken = false;

  @override
  void initState() {
    super.initState();
    final params = GoRouterState.of(context).uri.queryParameters;
    final emailParam = (params['email'] ?? '').trim();
    final tokenParam = (params['token'] ?? '').trim();
    if (emailParam.isNotEmpty) {
      _emailCtrl.text = emailParam.toLowerCase();
    }
    if (tokenParam.isEmpty) {
      _missingToken = true;
    } else {
      _token = tokenParam;
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() => _missingToken = true);
      return;
    }

    setState(() => _saving = true);
    final email = _emailCtrl.text.trim().toLowerCase();
    final password = _pwdCtrl.text;

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'complete_parent_setup',
        body: {
          'email': email,
          'token': token,
          'password': password,
        },
      );

      final data = response.data;
      final ok = response.status == 200 &&
          data is Map &&
          data['success'] == true;
      if (!ok) {
        final msg = _extractErrorMessage(data);
        if (kDebugMode) {
          debugPrint(
            '[ParentSetup] non-OK status=${response.status} data=$data',
          );
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
        setState(() => _saving = false);
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Parola a fost setată. Te poți autentifica acum.'),
        ),
      );
      context.go('/login');
    } on FunctionException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[ParentSetup] FunctionException status=${e.status} '
          'details=${e.details}',
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_extractErrorMessage(e.details))),
      );
      setState(() => _saving = false);
    } catch (e) {
      if (kDebugMode) debugPrint('[ParentSetup] $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A apărut o eroare. Încearcă din nou.'),
        ),
      );
      setState(() => _saving = false);
    }
  }

  /// Maps the Edge Function's structured error codes to Romanian
  /// copy. The function returns `{ error: <text>, code: <enum> }` so
  /// we prefer mapping by `code` and fall back to `error` text.
  static String _extractErrorMessage(dynamic body) {
    if (body is Map) {
      final code = body['code'];
      if (code is String) {
        switch (code) {
          case 'invalid_body':
            return 'Date invalide. Verifică emailul și parola.';
          case 'invalid_token':
            return 'Link invalid sau folosit deja. Cere o invitație nouă.';
          case 'token_expired':
            return 'Linkul a expirat. Cere o invitație nouă.';
          case 'token_locked':
            return 'Prea multe încercări pentru acest link. Cere o invitație nouă.';
          case 'password_update_failed':
            return 'Nu am putut seta parola. Încearcă din nou.';
          case 'server_error':
            return 'Eroare server. Încearcă din nou în câteva minute.';
        }
      }
      final err = body['error'];
      if (err is String && err.isNotEmpty) return err;
    }
    return 'A apărut o eroare. Încearcă din nou.';
  }

  String? _validateEmail(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Emailul este obligatoriu.';
    final emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRe.hasMatch(value)) return 'Email invalid.';
    return null;
  }

  String? _validatePwd(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return 'Parola este obligatorie.';
    if (value.length < 6) {
      return 'Parola trebuie să aibă minimum 6 caractere.';
    }
    return null;
  }

  String? _validateConfirm(String? v) {
    if ((v ?? '') != _pwdCtrl.text) return 'Parolele nu se potrivesc.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _missingToken
                  ? _MissingLinkBody(theme: theme)
                  : _buildForm(theme),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Setează-ți parola',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Alege o parolă pentru contul tău. O vei folosi la '
            'autentificările viitoare.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _emailCtrl,
            enabled: !_saving,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            validator: _validateEmail,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _pwdCtrl,
            obscureText: _obscurePwd,
            enabled: !_saving,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Parolă nouă',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              suffixIcon: IconButton(
                icon: Icon(_obscurePwd
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                tooltip: _obscurePwd
                    ? 'Afișează parola'
                    : 'Ascunde parola',
                onPressed: () =>
                    setState(() => _obscurePwd = !_obscurePwd),
              ),
            ),
            validator: _validatePwd,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirmCtrl,
            obscureText: _obscureConfirm,
            enabled: !_saving,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'Confirmă parola',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                tooltip: _obscureConfirm
                    ? 'Afișează parola'
                    : 'Ascunde parola',
                onPressed: () => setState(
                    () => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: _validateConfirm,
            onFieldSubmitted: (_) => _saving ? null : _submit(),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Setează parola'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _saving ? null : () => context.go('/login'),
            child: const Text('Înapoi la autentificare'),
          ),
        ],
      ),
    );
  }
}

class _MissingLinkBody extends StatelessWidget {
  const _MissingLinkBody({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.link_off, size: 40, color: theme.colorScheme.error),
        const SizedBox(height: 16),
        Text(
          'Link invalid sau incomplet',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Deschide linkul din emailul "Setează-ți parola". '
          'Dacă nu îl găsești, cere administratorului să trimită '
          'o invitație nouă.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.outline),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: () => context.go('/login'),
          child: const Text('Înapoi la autentificare'),
        ),
      ],
    );
  }
}
