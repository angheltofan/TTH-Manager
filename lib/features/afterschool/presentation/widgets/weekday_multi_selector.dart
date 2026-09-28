import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Compact multi-select chip picker for ISO weekdays (1 = Monday .. 7 =
/// Sunday). Emits `Set<int>` so callers can plug it directly into
/// `program.daysOfWeek` / `enrollment.attendanceDays`. Rendered as a
/// wrap of 7 short chips (L, Ma, Mi, J, V, S, D) — small enough for
/// phones without horizontal scroll.
///
/// [allowed] optionally restricts which chips are enabled. Used by the
/// enrollment form so a parent's per-child schedule can only select
/// among the program's own days. When [allowed] is null all seven days
/// are enabled. Values in [selected] outside [allowed] stay visible but
/// grayed out — the enrollment form uses this to surface a stale
/// attendance_days from before an admin narrowed the program.
class WeekdayMultiSelector extends StatelessWidget {
  const WeekdayMultiSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.allowed,
    this.minOne = true,
  });

  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;
  final Set<int>? allowed;

  /// When true, tapping the last selected chip is a no-op (empty set is
  /// invalid at DB level). The program form leaves it true; the
  /// enrollment form also true. Callers that need to clear should
  /// switch to "toate zilele" via a separate control instead.
  final bool minOne;

  static const _labels = <int, String>{
    1: 'L',
    2: 'Ma',
    3: 'Mi',
    4: 'J',
    5: 'V',
    6: 'S',
    7: 'D',
  };

  static const _fullLabels = <int, String>{
    1: 'Luni',
    2: 'Marți',
    3: 'Miercuri',
    4: 'Joi',
    5: 'Vineri',
    6: 'Sâmbătă',
    7: 'Duminică',
  };

  bool _isEnabled(int day) =>
      allowed == null || allowed!.contains(day);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final day in const [1, 2, 3, 4, 5, 6, 7])
          _Chip(
            label: _labels[day]!,
            tooltip: _fullLabels[day]!,
            selected: selected.contains(day),
            enabled: _isEnabled(day),
            onTap: () {
              if (!_isEnabled(day)) return;
              final next = {...selected};
              if (next.contains(day)) {
                if (minOne && next.length == 1) return;
                next.remove(day);
              } else {
                next.add(day);
              }
              onChanged(next);
            },
            theme: theme,
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.tooltip,
    required this.selected,
    required this.enabled,
    required this.onTap,
    required this.theme,
  });

  final String label;
  final String tooltip;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final Color border;
    if (!enabled) {
      bg = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3);
      fg = theme.colorScheme.outline;
      border = theme.colorScheme.outline.withValues(alpha: 0.2);
    } else if (selected) {
      bg = AppColors.purple;
      fg = Colors.white;
      border = AppColors.purple;
    } else {
      bg = theme.scaffoldBackgroundColor;
      fg = theme.colorScheme.onSurface;
      border = theme.colorScheme.outline.withValues(alpha: 0.4);
    }

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border, width: selected ? 1.5 : 1),
          ),
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: fg,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Formats a `Set<int>` of ISO weekdays as a compact, human-readable
/// label. Contiguous runs collapse to "L-V"; disjoint sets stay as
/// individual short labels separated by "·". Used in list rows so a
/// program says "L-V" and a child's L/W/F shows as "L · Mi · V".
String formatIsoWeekdaysShort(Iterable<int> days) {
  final sorted = days.toSet().toList()..sort();
  if (sorted.isEmpty) return '—';
  const short = {1: 'L', 2: 'Ma', 3: 'Mi', 4: 'J', 5: 'V', 6: 'S', 7: 'D'};
  final parts = <String>[];
  int runStart = sorted.first;
  int prev = sorted.first;
  for (int i = 1; i <= sorted.length; i++) {
    final atEnd = i == sorted.length;
    if (atEnd || sorted[i] != prev + 1) {
      if (runStart == prev) {
        parts.add(short[runStart]!);
      } else if (prev - runStart == 1) {
        // Two-day run — keep as "X · Y" rather than "X-Y" for visual clarity.
        parts.add('${short[runStart]!} · ${short[prev]!}');
      } else {
        parts.add('${short[runStart]!}-${short[prev]!}');
      }
      if (!atEnd) {
        runStart = sorted[i];
        prev = sorted[i];
      }
    } else {
      prev = sorted[i];
    }
  }
  return parts.join(' · ');
}
