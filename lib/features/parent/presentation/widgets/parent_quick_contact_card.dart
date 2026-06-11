import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../children/presentation/widgets/details_section_card.dart';

// Canonical Tales & Tech HUB contact constants. Single source of truth
// for every parent surface that exposes a phone / WhatsApp / email
// launcher (dashboard + About). Exported so the About page can render
// the same numbers verbatim without redefining them.
//
// Storage convention:
//   • kParentContactPhoneDisplay   — visual format shown as text.
//   • kParentContactPhoneTel       — tel: URI path (digits only).
//   • kParentContactPhoneWhatsApp  — wa.me path (E.164 digits, no '+').
//   • kParentContactEmail          — mailto: address.
//   • kParentContactLocation       — display name of the studio location.
const String kParentContactPhoneDisplay = '0750 255 877';
const String kParentContactPhoneTel = '0750255877';
const String kParentContactPhoneWhatsApp = '40750255877';
const String kParentContactEmail = 'talesandtechhub@gmail.com';
const String kParentContactLocation = 'Suceava';

/// Compact "Ai nevoie de ajutor?" card used on the parent dashboard
/// and the About page. Renders inside the staff [DetailsSectionCard]
/// shell so the parent area visually inherits the rest of the app's
/// card chrome.
///
/// Two outlined buttons: Sună-ne (`tel:` deep link) and WhatsApp
/// (`https://wa.me/<digits>`). On launch failure shows a Romanian
/// snackbar; never silently fails.
class ParentQuickContactCard extends StatelessWidget {
  const ParentQuickContactCard({
    super.key,
    this.title = 'Ai nevoie de ajutor?',
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DetailsSectionCard(
      title: title,
      iconData: Icons.support_agent_rounded,
      iconColor: AppColors.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Suntem aici să te ajutăm cu orice informație despre copilul tău.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 12),
          // Buttons wrap when the column is narrow so the card stays
          // compact across all breakpoints.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.phone, size: 16),
                label: const Text('Sună-ne'),
                onPressed: () =>
                    launchParentTel(context, kParentContactPhoneTel),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                label: const Text('WhatsApp'),
                onPressed: () => launchParentWhatsApp(
                    context, kParentContactPhoneWhatsApp),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Launch helpers ──────────────────────────────────────────────────────────
//
// Top-level functions so both the quick-contact card and any future
// parent-side surface (e.g. an in-page CTA) can share the same behaviour.

Future<void> launchParentTel(BuildContext context, String phone) async {
  final uri = Uri(scheme: 'tel', path: phone);
  await _launchOrSnackbar(
    context,
    uri,
    'Nu s-a putut deschide telefonul.',
  );
}

Future<void> launchParentWhatsApp(BuildContext context, String phone) async {
  // wa.me expects the international number without leading '+' or spaces.
  final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  final uri = Uri.parse('https://wa.me/$digits');
  await _launchOrSnackbar(
    context,
    uri,
    'Nu s-a putut deschide WhatsApp.',
    mode: LaunchMode.externalApplication,
  );
}

Future<void> launchParentEmail(BuildContext context, String address) async {
  final uri = Uri(scheme: 'mailto', path: address);
  await _launchOrSnackbar(
    context,
    uri,
    'Nu s-a putut deschide aplicația de e-mail.',
  );
}

Future<void> _launchOrSnackbar(
  BuildContext context,
  Uri uri,
  String failureMessage, {
  LaunchMode mode = LaunchMode.platformDefault,
}) async {
  try {
    final ok = await launchUrl(uri, mode: mode);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failureMessage)),
      );
    }
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(failureMessage)),
    );
  }
}
