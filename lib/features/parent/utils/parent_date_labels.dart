/// Romanian date / day-of-week formatters used by the parent dashboard.
///
/// Kept separate from the staff-side `core/utils/date_utils.dart` so the
/// parent area has full ownership of its short-form Romanian copy
/// (e.g. "Luni, 2 iun.", "LUN", "MAR").
library;

const _kRoMonthsShort = <String>[
  'ian', 'feb', 'mar', 'apr', 'mai', 'iun',
  'iul', 'aug', 'sep', 'oct', 'noi', 'dec',
];

const _kRoWeekdayShortUpper = <String>[
  // DateTime.weekday: 1 = Monday … 7 = Sunday.
  'LUN', 'MAR', 'MIE', 'JOI', 'VIN', 'SÂM', 'DUM',
];

const _kRoWeekdayFull = <String>[
  'Luni', 'Marți', 'Miercuri', 'Joi', 'Vineri', 'Sâmbătă', 'Duminică',
];

/// "Luni, 2 iun." — used on the "Următorul atelier" KPI.
String formatRoFullDay(DateTime date) {
  final weekday = _kRoWeekdayFull[(date.weekday - 1).clamp(0, 6)];
  final month = _kRoMonthsShort[(date.month - 1).clamp(0, 11)];
  return '$weekday, ${date.day} $month.';
}

/// "2 iun." — short label for the weekly schedule rows.
String formatRoShortDayMonth(DateTime date) {
  final month = _kRoMonthsShort[(date.month - 1).clamp(0, 11)];
  return '${date.day} $month.';
}

/// "LUN" / "JOI" — three-letter uppercase weekday for the weekly
/// schedule's left-side date chip.
String formatRoWeekdayChip(DateTime date) {
  return _kRoWeekdayShortUpper[(date.weekday - 1).clamp(0, 6)];
}

/// "Luni 26 mai 2025" — long form used by activity rows. Slightly more
/// terse than `core/utils/date_utils.dart#formatDateLong` so the
/// weekday is included without the year repeated next to the time.
String formatRoActivityDate(DateTime date) {
  final weekday = _kRoWeekdayFull[(date.weekday - 1).clamp(0, 6)];
  final month = _kRoMonthsShort[(date.month - 1).clamp(0, 11)];
  return '$weekday, ${date.day} $month. ${date.year}';
}
