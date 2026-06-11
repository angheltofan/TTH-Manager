import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../providers/parent_base_provider.dart';

/// Parent dashboard greeting (top of the page).
///
/// Mirrors the staff `DashboardHeader` typography exactly
/// (`headlineSmall w700 letterSpacing -0.3`) and renders the same
/// rounded date chip on the right. The subtitle is pluralised based
/// on the number of linked children — reads
/// [parentLinkedChildrenBaseProvider] directly so the count is the
/// already-cached base value (no extra query).
class ParentGreeting extends ConsumerWidget {
  const ParentGreeting({super.key, required this.firstName});

  /// Display name for the greeting. Resolved by the caller from the
  /// parent profile / email fallback so this widget stays purely
  /// presentational.
  final String firstName;

  static String _timeOfDay() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bună dimineața';
    if (h < 18) return 'Bună ziua';
    return 'Bună seara';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

    // Pluralise the subtitle: singular when the parent has exactly one
    // linked child, plural for 0 (welcome state) and 2+. Falls back to
    // the plural form while the base provider is loading — it is the
    // safer guess and avoids a flash from "copilului" → "copiilor".
    final base = ref.watch(parentLinkedChildrenBaseProvider).valueOrNull;
    final childCount = base?.basics.length ?? 0;
    final subtitleText = childCount == 1
        ? 'Iată ce se întâmplă în atelierele copilului tău.'
        : 'Iată ce se întâmplă în atelierele copiilor tăi.';

    final displayName = firstName.isEmpty ? '' : ', $firstName';
    final greetingText = '${_timeOfDay()}$displayName! 👋';

    final today = DateTime.now();

    final greetingCol = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greetingText,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitleText,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );

    final dateBlock = _DateBlock(date: today);

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          greetingCol,
          const SizedBox(height: 10),
          dateBlock,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: greetingCol),
        dateBlock,
      ],
    );
  }
}

// ── Date chip (mirrors staff DashboardHeader._DateBlock) ───────────────────

class _DateBlock extends StatelessWidget {
  const _DateBlock({required this.date});
  final DateTime date;

  static const _months = <String>[
    '',
    'ianuarie', 'februarie', 'martie', 'aprilie', 'mai', 'iunie',
    'iulie', 'august', 'septembrie', 'octombrie', 'noiembrie', 'decembrie',
  ];
  static const _days = <String>[
    '', 'Luni', 'Marți', 'Miercuri', 'Joi', 'Vineri', 'Sâmbătă', 'Duminică',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = '${date.day} ${_months[date.month]} ${date.year}';
    final dayStr = _days[date.weekday];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_today_outlined,
              size: 14, color: AppColors.purple),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                dateStr,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                dayStr,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.outline,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Greeting name fallback chain: `profile.firstName` → email local-part →
/// empty. Lives in this file so the shell can compute it once and pass
/// it to [ParentGreeting] without leaking the resolution logic into the
/// shell.
String resolveParentGreetingName(String? firstName, String? email) {
  final f = firstName?.trim() ?? '';
  if (f.isNotEmpty) return f;
  final e = email?.trim() ?? '';
  if (e.contains('@')) {
    final local = e.split('@').first;
    if (local.isNotEmpty) {
      return local
          .split(RegExp(r'[._\-]'))
          .where((s) => s.isNotEmpty)
          .map((s) => s[0].toUpperCase() + s.substring(1))
          .join(' ');
    }
  }
  return '';
}
