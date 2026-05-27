import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/auth_providers.dart';

/// Code-based fallback for the parent invite flow. Mounted at
/// `/parent-setup`. Used when the email's magic link path is consumed
/// upstream by an email security scanner (Defender / Mimecast /
/// Proofpoint / SafeLinks) before the parent can click it. The same
/// invite email also contains a 6-digit OTP (`{{ .Token }}` in the
/// template) — this page verifies that code and sets the password.
///
/// Flow:
///   1. Parent enters email + 6-digit code + new password.
///   2. `verifyOTP(type: invite)` exchanges the code for a session.
///   3. `updateUser(password)` sets the chosen password.
///   4. Route by role (parent → /parent, staff → /dashboard).
class ParentSetupPage extends ConsumerStatefulWidget {
  const ParentSetupPage({super.key});

  @override
  ConsumerState<ParentSetupPage> createState() => _ParentSetupPageState();
}

class _ParentSetupPageState extends ConsumerState<ParentSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _saving = false;
  bool _obscurePwd = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _pwdCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    final email = _emailCtrl.text.trim().toLowerCase();
    final token = _codeCtrl.text.trim();
    final password = _pwdCtrl.text;

    try {
      // Step 1 — verify the 6-digit invite code. On success Supabase
      // mints a session for this email, after which updateUser can run.
      await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.invite,
        email: email,
        token: token,
      );

      if (!mounted) return;

      // Step 2 — set the password the parent just chose.
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: password),
      );

      if (!mounted) return;

      ref.invalidate(currentProfileProvider);
      final profile = await ref.read(currentProfileProvider.future);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Parola a fost setată cu succes.')),
      );

      // Mirror set_password_page role routing exactly. Unknown role
      // falls back to /login so an inconsistent account isn't dropped
      // into a staff surface.
      if (profile == null) {
        context.go('/login');
      } else if (profile.isParent) {
        context.go('/parent');
      } else if (profile.isAdmin || profile.isTrainer) {
        context.go('/dashboard');
      } else {
        context.go('/login');
      }
    } on AuthException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[ParentSetup] AuthException statusCode=${e.statusCode} '
          'code=${e.code} message=${e.message}',
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_humanizeAuthError(e))),
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

  static String _humanizeAuthError(AuthException e) {
    final code = (e.code ?? '').toLowerCase();
    final msg = e.message.toLowerCase();
    if (code == 'otp_expired' || msg.contains('expired')) {
      return 'Codul a expirat. Cere o invitație nouă.';
    }
    if (code == 'otp_invalid' ||
        code == 'invalid_credentials' ||
        msg.contains('invalid') ||
        msg.contains('token')) {
      return 'Cod incorect. Verifică emailul și codul primit pe email.';
    }
    if (msg.contains('weak') || msg.contains('password')) {
      return 'Parola este prea slabă. Încearcă una mai puternică.';
    }
    if (e.statusCode == '429' ||
        msg.contains('rate') ||
        msg.contains('too many')) {
      return 'Prea multe încercări. Așteaptă câteva minute și încearcă din nou.';
    }
    return 'Eroare: ${e.message}';
  }

  String? _validateEmail(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Emailul este obligatoriu.';
    final emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRe.hasMatch(value)) return 'Email invalid.';
    return null;
  }

  String? _validateCode(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Codul este obligatoriu.';
    if (value.length != 6 || int.tryParse(value) == null) {
      return 'Codul trebuie să aibă 6 cifre.';
    }
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
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Setează parola cu cod',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Folosește codul de 6 cifre primit pe email pentru a-ți crea parola.',
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
                      controller: _codeCtrl,
                      enabled: !_saving,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      textInputAction: TextInputAction.next,
                      maxLength: 6,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        labelText: 'Cod din email (6 cifre)',
                        counterText: '',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: _validateCode,
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
                      onPressed:
                          _saving ? null : () => context.go('/login'),
                      child: const Text('Înapoi la autentificare'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
