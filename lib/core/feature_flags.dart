/// Compile-time feature switches.
///
/// Keeping these in a single file lets us leave in-progress Flutter code
/// in the tree while the dependent server-side migration has not been
/// applied yet. Flip the flag locally when the migration lands.
library;

/// Enables "Prezență în altă grupă" (visitor attendance credit routing).
///
/// Depends on migration `20261014_flexible_attendance_credit.sql`
/// (adds `attendance.credited_series_id` + validator triggers + the
/// credit-aware recalc). When this flag is `false`:
///   • SELECTs do not request `credited_series_id` (schemas without
///     the column no longer throw PostgrestException 42703);
///   • visitor rows are not surfaced on the roster;
///   • the "+ Adaugă participant din altă grupă" action is hidden;
///   • realtime invalidation for the credited series is skipped;
///   • parent portal recent activity never flags a row as a visitor.
/// The Flutter Phase B implementation stays in-tree, ready to activate
/// in one place.
const bool kFlexibleAttendanceCreditEnabled = false;
