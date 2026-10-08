import 'package:flutter/widgets.dart';

/// Unified activity type consumed by the dashboard Activity Calendar.
/// Three concrete sources map onto this shape:
///   • Scheduled workshop  (public.scheduled_workshops, blue)
///   • Demo workshop       (public.demo_workshops, orange)
///   • Afterschool session (public.afterschool_sessions +
///     synthesized from active programs for future days, green)
enum CalendarActivityCategory { workshop, demo, afterschool }

/// One activity on the calendar.
///
/// `date` is a date-only `DateTime` at local midnight (00:00:00).
/// `startTime` / `endTime` are the HH:mm strings as they come from the
/// database — we never try to parse them into TimeOfDay here, so a
/// NULL time just renders as "—".
class CalendarActivity {
  const CalendarActivity({
    required this.id,
    required this.category,
    required this.date,
    required this.title,
    this.startTime,
    this.endTime,
    this.subtitle,
    this.workshopType,
    this.onOpen,
  });

  /// Stable identity for Flutter widget keys. Composed as
  /// `"<category>:<row id>"` so a workshop and a demo with the same
  /// UUID (extremely unlikely but possible) do not collide.
  final String id;

  final CalendarActivityCategory category;

  /// Local date, 00:00:00 — the day this activity sits on in the
  /// calendar grid.
  final DateTime date;

  final String title;

  /// Database HH:mm (or null when the source row has no time, e.g. a
  /// future afterschool day synthesized from a program's weekday set).
  final String? startTime;
  final String? endTime;

  /// Secondary line — trainer full name, program name, afterschool
  /// variant, etc. Rendered under the title in the popover.
  final String? subtitle;

  /// `scheduled_workshops.workshop_type` for workshop/demo rows.
  /// Powers the small type icon in the popover.
  final String? workshopType;

  /// Opens the appropriate TTH Manager route for this activity.
  /// Non-null means the popover row is tappable; null means the row
  /// is informational.
  final VoidCallback? onOpen;

  /// Chronological comparator for popover ordering.
  static int compareByTime(CalendarActivity a, CalendarActivity b) {
    final at = a.startTime ?? '99:99';
    final bt = b.startTime ?? '99:99';
    final cmp = at.compareTo(bt);
    if (cmp != 0) return cmp;
    return a.title.compareTo(b.title);
  }
}

/// Visual metadata for the three categories. Centralised so the
/// calendar cell dots, the popover accent bar, and the legend all
/// pull from one source.
class CalendarCategoryStyle {
  const CalendarCategoryStyle({
    required this.color,
    required this.label,
    required this.icon,
  });
  final Color color;
  final String label;
  final IconData icon;
}
