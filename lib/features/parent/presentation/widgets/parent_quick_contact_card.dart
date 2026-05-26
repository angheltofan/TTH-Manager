import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'parent_section_card.dart';

// Placeholder contact constants for v1. Real numbers come later.
const String _kContactPhone = '+40XXXXXXXXX';
const String _kContactWhatsApp = '+40XXXXXXXXX';

/// Shared Quick-Contact card used on the parent dashboard and the
/// About page. Two outlined buttons: Sună (`tel:` deep link) and
/// WhatsApp (`https://wa.me/<digits>`). On launch failure, shows a
/// Romanian snackbar; never silently fails.
class ParentQuickContactCard extends StatelessWidget {
  const ParentQuickContactCard({super.key, this.title = 'Contact rapid'});

  final String title;

  @override
  Widget build(BuildContext context) {
    return ParentSectionCard(
      title: title,
      icon: Icons.support_agent_rounded,
      iconColor: const Color(0xFFF59E0B),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.phone),
            label: const Text('Sună'),
            onPressed: () => launchParentTel(context, _kContactPhone),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            label: const Text('WhatsApp'),
            onPressed: () =>
                launchParentWhatsApp(context, _kContactWhatsApp),
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
