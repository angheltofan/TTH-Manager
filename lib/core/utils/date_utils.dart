String formatDate(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '$d.$m.${date.year}';
}

/// Romanian weekday name for a date — "Luni" through "Duminică".
/// `DateTime.weekday` is 1 (Mon) .. 7 (Sun).
String weekdayNameRo(DateTime date) {
  const names = [
    'Luni', 'Marți', 'Miercuri', 'Joi', 'Vineri', 'Sâmbătă', 'Duminică',
  ];
  return names[date.weekday - 1];
}

/// "Miercuri, 30.09.2026" — compact weekday + numeric date used by
/// the Demo list and any surface that wants the weekday context
/// without the long month name.
String formatDateWithWeekday(DateTime date) =>
    '${weekdayNameRo(date)}, ${formatDate(date)}';

String formatDateLong(DateTime date) {
  const months = [
    'ianuarie', 'februarie', 'martie', 'aprilie', 'mai', 'iunie',
    'iulie', 'august', 'septembrie', 'octombrie', 'noiembrie', 'decembrie',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String formatTime(DateTime time) {
  final h = time.hour.toString().padLeft(2, '0');
  final min = time.minute.toString().padLeft(2, '0');
  return '$h:$min';
}

String formatDateTime(DateTime dateTime) {
  return '${formatDate(dateTime)} ${formatTime(dateTime)}';
}

String formatTimeString(String hhmm) => hhmm.length >= 5 ? hhmm.substring(0, 5) : hhmm;
