import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/auth_providers.dart';

/// First-time password setup (after invite acceptance) and reset password
/// (after recovery email). Mounted at `/set-password`. The page assumes a
/// valid session already exists — the `/auth/callback` flow lands here
/// only after `getSessionFromUrl` has succeeded.
class SetPasswordPage extends ConsumerStatefulWidget {
  const SetPasswordPage({super.key});

  @override
  ConsumerState<SetPasswordPage> createState() => _SetPasswordPageState();
}

class _SetPasswordPageState extends ConsumerState<SetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _pwdCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _saving = false;
  bool _obscurePwd = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _pwdCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _pwdCtrl.text),
      );

      if (!mounted) return;
      ref.invalidate(currentProfileProvider);
      final profile = await ref.read(currentProfileProvider.future);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Parola a fost setată cu succes.')),
      );

      // Route by role. Unknown / missing role falls back to /login so an
      // account in an inconsistent state isn't dropped into a staff
      // surface by default.
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_humanizeAuthError(e))),
      );
      setState(() => _saving = false);
    } catch (e) {
      if (kDebugMode) debugPrint('[SetPassword] $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('A apărut o eroare. Încearcă din nou.')),
      );
      setState(() => _saving = false);
    }
  }

  static String _humanizeAuthError(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('weak') || msg.contains('password')) {
      return 'Parola este prea slabă. Încearcă una mai puternică.';
    }
    return 'Eroare: ${e.message}';
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
      body: Center(
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
                    'Setează parola',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Alege o parolă pentru contul tău. O vei folosi la autentificările viitoare.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _pwdCtrl,
                    obscureText: _obscurePwd,
                    enabled: !_saving,
                    autofillHints: const [AutofillHints.newPassword],
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
