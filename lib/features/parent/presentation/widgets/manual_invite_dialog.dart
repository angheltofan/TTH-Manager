import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/parent_link.dart';

/// Read-only dialog shown after `generate_parent_setup_invite` succeeds.
/// Surfaces the four artifacts the admin needs to hand off the
/// invitation manually (WhatsApp, Gmail, SMS, …):
///
///   • parent email (so the admin pastes the right address)
///   • activation code (the raw token, ~43 base64url chars)
///   • setup URL (preloads token+email on `/parent-setup`)
///   • full ready-to-copy message in Romanian
///
/// "Copiază mesajul" copies the bundled message verbatim. Individual
/// rows can also be copied via their trailing icon.
class ManualInviteDialog extends StatelessWidget {
  const ManualInviteDialog({super.key, required this.invite});

  final ManualParentInvite invite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expires = MaterialLocalizations.of(context)
        .formatMediumDate(invite.expiresAt.toLocal());
    final expiresTime = TimeOfDay.fromDateTime(invite.expiresAt.toLocal())
        .format(context);

    return AlertDialog(
      title: const Text('Copiază invitația'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Trimite aceste informații părintelui prin WhatsApp, Gmail sau '
                'SMS. Codul expiră pe $expires, ora $expiresTime.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 16),
              _CopyableField(label: 'Email părinte', value: invite.email),
              const SizedBox(height: 10),
              _CopyableField(
                label: 'Cod activare',
                value: invite.code,
                monospace: true,
              ),
              const SizedBox(height: 10),
              _CopyableField(label: 'Link setare parolă', value: invite.setupUrl),
              const SizedBox(height: 18),
              Text(
                'Mesaj gata de copiat',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color:
                        theme.colorScheme.outline.withValues(alpha: 0.25),
                  ),
                ),
                child: SelectableText(
                  invite.message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'După introducerea codului, părintele își setează parola și '
                'are acces la contul de părinte.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Închide'),
        ),
        FilledButton.icon(
          onPressed: () => _copyAndConfirm(context, invite.message),
          icon: const Icon(Icons.copy_all_rounded, size: 16),
          label: const Text('Copiază mesajul'),
        ),
      ],
    );
  }

  static Future<void> _copyAndConfirm(
      BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mesajul a fost copiat în clipboard.')),
    );
  }
}

class _CopyableField extends StatelessWidget {
  const _CopyableField({
    required this.label,
    required this.value,
    this.monospace = false,
  });

  final String label;
  final String value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: monospace ? 'monospace' : null,
                    fontSize: 13,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copiază',
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.copy_rounded,
                    size: 16, color: AppColors.purple),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: value));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$label copiat.')),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
