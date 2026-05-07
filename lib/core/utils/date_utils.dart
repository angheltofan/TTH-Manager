String formatDate(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '$d.$m.${date.year}';
}

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
