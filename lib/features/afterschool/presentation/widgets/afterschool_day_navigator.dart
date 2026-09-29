import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// A ← <label> → strip for picking the date shown on the Astăzi page.
///
/// Layout:
///   [ ← ]  [ Astăzi · date-label ]  [ → ]
///
/// When [date] equals today, a small "Astăzi" pill is prefixed inside
/// the middle button. When it doesn't, a separate "Azi" reset button
/// is exposed as a trailing action so the user can jump back with one
/// tap.
class AfterschoolDayNavigator extends StatelessWidget {
  const AfterschoolDayNavigator({
    super.key,
    required this.date,
    required this.onDateChanged,
  });

  final DateTime date;
  final ValueChanged<DateTime> onDateChanged;

  static const _monthsRo = [
    'ianuarie',
    'februarie',
    'martie',
    'aprilie',
    'mai',
    'iunie',
    'iulie',
    'august',
    'septembrie',
    'octombrie',
    'noiembrie',
    'decembrie',
  ];

  static const _weekdaysRo = [
    'luni', 'marți', 'miercuri', 'joi', 'vineri', 'sâmbătă', 'duminică',
  ];

  bool get _isToday {
    final now = DateTime.now();
    return now.year == date.year &&
        now.month == date.month &&
        now.day == date.day;
  }

  DateTime _stripTime(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      initialDate: date,
    );
    if (picked != null) {
      onDateChanged(_stripTime(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label =
        '${_weekdaysRo[date.weekday - 1]}, ${date.day} '
        '${_monthsRo[date.month - 1]} ${date.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Ziua anterioară',
            onPressed: () =>
                onDateChanged(_stripTime(date.subtract(const Duration(days: 1)))),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _pick(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isToday) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              AppColors.purple.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text('ASTĂZI',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.purple)),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.calendar_today,
                        size: 14, color: theme.colorScheme.outline),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Ziua următoare',
            onPressed: () =>
                onDateChanged(_stripTime(date.add(const Duration(days: 1)))),
          ),
          if (!_isToday)
            TextButton(
              onPressed: () => onDateChanged(_stripTime(DateTime.now())),
              child: const Text('Azi'),
            ),
        ],
      ),
    );
  }
}
