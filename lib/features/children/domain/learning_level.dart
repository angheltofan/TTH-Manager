/// The four manually-managed TTH learning levels mapped to the
/// `children.current_level` column.
///
/// Deliberately NOT a Dart enum: the DB stores the canonical label as
/// text and admins may want to display it exactly as stored. A tiny
/// value-class with constants keeps serialization trivial and avoids
/// an index-shift hazard if the ordering is ever changed.
///
/// Companion column is `children.level_progress` (0..100). Both are
/// nullable: a NULL `currentLevel` means "not placed yet" and the UI
/// must render accordingly rather than guessing a default.
class LearningLevel {
  const LearningLevel._(this.value);

  final String value;

  static const LearningLevel explorer = LearningLevel._('Explorer');
  static const LearningLevel builder = LearningLevel._('Builder');
  static const LearningLevel programmer = LearningLevel._('Programmer');
  static const LearningLevel architect = LearningLevel._('Architect');

  /// Canonical ordered list — matches the DB CHECK constraint on
  /// `children.current_level`.
  static const List<LearningLevel> values = [
    explorer,
    builder,
    programmer,
    architect,
  ];

  /// Parses the raw string. Returns `null` for any value outside the
  /// canonical set (including the empty string and `null`). Callers
  /// treat null as "not placed yet".
  static LearningLevel? tryParse(String? raw) {
    if (raw == null) return null;
    for (final level in values) {
      if (level.value == raw) return level;
    }
    return null;
  }

  /// True iff [progress] is a valid 0..100 integer. Used before
  /// shipping an update to the DB — the DB CHECK is the real gate
  /// but failing fast on the client avoids a round-trip.
  static bool isValidProgress(int? progress) {
    if (progress == null) return true;
    return progress >= 0 && progress <= 100;
  }

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LearningLevel && other.value == value);

  @override
  int get hashCode => value.hashCode;
}
