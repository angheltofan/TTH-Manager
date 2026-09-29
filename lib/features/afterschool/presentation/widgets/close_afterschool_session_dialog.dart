import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../children/presentation/widgets/child_form_helpers.dart';
import '../../providers/afterschool_providers.dart';

/// Dialog for closing an Afterschool session. Requires a non-empty
/// reason before allowing submit — the reason is captured on
/// `afterschool_sessions.closed_reason` for audit.
///
/// Returns true if the RPC succeeded, false / null otherwise.
Future<bool?> showCloseAfterschoolSessionDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String sessionId,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => _CloseDialog(sessionId: sessionId),
  );
}

class _CloseDialog extends ConsumerStatefulWidget {
  const _CloseDialog({required this.sessionId});
  final String sessionId;

  @override
  ConsumerState<_CloseDialog> createState() => _CloseDialogState();
}

class _CloseDialogState extends ConsumerState<_CloseDialog> {
  final _ctrl = TextEditingController();
  bool _saving = false;
  String? _err;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Închide sesiunea'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ziua va fi marcată închisă. Prezențele existente rămân, '
              'dar nu se pot adăuga sau modifica până la redeschidere.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            ChildFormField(
              label: 'Motiv',
              required: true,
              child: TextFormField(
                controller: _ctrl,
                maxLines: 2,
                decoration: buildChildFormInputDeco(theme).copyWith(
                    hintText: 'ex: Vacanță · Sărbătoare · Închidere excepțională'),
                onChanged: (_) {
                  if (_err != null) setState(() => _err = null);
                },
              ),
            ),
            if (_err != null) ...[
              const SizedBox(height: 8),
              Text(_err!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Renunță'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          icon: _saving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.lock_outline),
          label: const Text('Închide ziua'),
          onPressed: _saving ? null : _onSubmit,
        ),
      ],
    );
  }

  Future<void> _onSubmit() async {
    final reason = _ctrl.text.trim();
    if (reason.isEmpty) {
      setState(() => _err = 'Motivul este obligatoriu.');
      return;
    }
    setState(() {
      _saving = true;
      _err = null;
    });
    try {
      await ref
          .read(afterschoolSessionsRepositoryProvider)
          .closeSession(sessionId: widget.sessionId, reason: reason);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _saving = false;
        _err = _pretty(e.toString());
      });
    }
  }

  String _pretty(String raw) {
    if (raw.contains('insufficient_privileges')) {
      return 'Doar personalul poate închide sesiuni.';
    }
    if (raw.contains('session_not_found')) {
      return 'Sesiunea nu mai există. Reîncarcă pagina.';
    }
    return raw;
  }
}
