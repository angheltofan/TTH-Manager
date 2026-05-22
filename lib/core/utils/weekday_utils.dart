// Day-of-week index helpers for consistent Romanian + English weekday ordering.
//
// Returns 0 for Monday, 6 for Sunday, and 99 for unrecognised values
// (unknown days sort to the end rather than crashing).

const Map<String, int> _kWeekdayOrder = {
  // Romanian canonical + common variant spellings
  'luni': 0,
  'marți': 1,
  'marti': 1,
  'miercuri': 2,
  'joi': 3,
  'vineri': 4,
  'sâmbătă': 5,
  'sambata': 5,
  'sâmbata': 5,
  'duminică': 6,
  'duminica': 6,
  // English
  'monday': 0,
  'tuesday': 1,
  'wednesday': 2,
  'thursday': 3,
  'friday': 4,
  'saturday': 5,
  'sunday': 6,
};

/// Returns the week-order index (0 = Monday … 6 = Sunday) for [day].
/// Case-insensitive.  Returns 99 for unrecognised values.
int weekdayIndex(String? day) {
  if (day == null || day.isEmpty) return 99;
  return _kWeekdayOrder[day.trim().toLowerCase()] ?? 99;
}

/// Compares two items by weekday → start_time → title (all ascending).
/// Pass nullable [titleA]/[titleB] if no title tie-break is needed.
int compareByWeekday({
  required String? dayA,
  required String? dayB,
  required String timeA,
  required String timeB,
  String? titleA,
  String? titleB,
}) {
  final dayCmp = weekdayIndex(dayA).compareTo(weekdayIndex(dayB));
  if (dayCmp != 0) return dayCmp;
  final timeCmp = timeA.compareTo(timeB);
  if (timeCmp != 0) return timeCmp;
  if (titleA != null && titleB != null) return titleA.compareTo(titleB);
  return 0;
}
