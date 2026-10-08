import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../afterschool/providers/afterschool_providers.dart';
import '../../demo_workshops/providers/demo_workshops_providers.dart';
import '../domain/calendar_activity.dart';
import 'dashboard_providers.dart';

/// Date-only key for the dashboard Activity Calendar's range query.
///
/// Equality is defined on day resolution — a `(from, to)` pair with the
/// same year/month/day on both sides matches regardless of time
/// component — which lets `.family(...)` cache by week / month range
/// without the DateTime-identity trap.
@immutable
class CalendarRangeKey {
  CalendarRangeKey(DateTime from, DateTime to)
    : from = DateTime(from.year, from.month, from.day),
      to = DateTime(to.year, to.month, to.day);

  final DateTime from;
  final DateTime to;

  @override
  bool operator ==(Object other) =>
      other is CalendarRangeKey && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => 'CalendarRangeKey($from..$to)';
}

/// Returns `Map<DateTime, List<CalendarActivity>>` keyed by the local
/// midnight DateTime of the day. Spans the inclusive [from, to]
/// window of the key. Autodispose + family so a view-switch does not
/// retain stale ranges forever.
///
/// Afterschool coverage:
///   • For dates ≤ today, we query materialized `afterschool_sessions`
///     for each applicable program — those are already lazily created
///     by other reads.
///   • For future dates, we synthesize entries from each active
///     `AfterschoolProgram` whose `daysOfWeek` + active window
///     intersect the day. We do NOT call the server-side
///     `generate_afterschool_sessions_window` RPC — that is a write
///     and the brief forbids any schema mutation from this feature.
final activityCalendarProvider = FutureProvider.autoDispose
    .family<Map<DateTime, List<CalendarActivity>>, CalendarRangeKey>((
      ref,
      key,
    ) async {
      final dashboardRepo = ref.watch(dashboardRepositoryProvider);
      final demoRepo = ref.watch(demoWorkshopsRepositoryProvider);
      final afsSessionsRepo = ref.watch(afterschoolSessionsRepositoryProvider);
      final programs = await ref.watch(afterschoolProgramsProvider.future);

      // All three range queries run in parallel. Stage-3-era
      // afterschool code called `fetchByDate` per (program, day) —
      // Stage 3.2.4 adds `fetchForDateRange` so one SELECT covers
      // the entire visible window across every program.
      final workshopsFuture = dashboardRepo.getScheduledWorkshopsBetween(
        key.from,
        key.to,
      );
      final demosFuture = demoRepo.getBetween(key.from, key.to);
      final afsSessionsFuture = afsSessionsRepo.fetchForDateRange(
        from: key.from,
        to: key.to,
      );

      final results = await Future.wait([
        workshopsFuture,
        demosFuture,
        afsSessionsFuture,
      ]);
      final workshops = results[0] as List<dynamic>;
      final demos = results[1] as List<dynamic>;
      final afsSessions = results[2] as List<dynamic>;

      final out = <DateTime, List<CalendarActivity>>{};
      void add(CalendarActivity a) {
        out.putIfAbsent(a.date, () => []).add(a);
      }

      // ── Workshops (blue) ─────────────────────────────────────────
      for (final w in workshops) {
        final d = DateTime(
          w.workshopDate.year,
          w.workshopDate.month,
          w.workshopDate.day,
        );
        add(
          CalendarActivity(
            id: 'workshop:${w.id}',
            category: CalendarActivityCategory.workshop,
            date: d,
            title: w.title,
            startTime: w.startTime,
            endTime: w.endTime,
            subtitle: w.trainerName,
            workshopType: w.workshopType,
          ),
        );
      }

      // ── Demo workshops (orange) ──────────────────────────────────
      // Dashboard rule: cancelled demos drop out of the admin
      // dashboard. Mirror `isDashboardTodayVisible` so a calendar day
      // for today matches the "Ateliere programate azi" roster below.
      // Non-today days keep every status so an admin can see a
      // reschedule-to-tomorrow or a converted-last-week.
      final today = DateTime.now();
      final todayKey = DateTime(today.year, today.month, today.day);
      for (final d in demos) {
        final day = DateTime(
          d.demoDate.year,
          d.demoDate.month,
          d.demoDate.day,
        );
        if (day == todayKey && d.status == 'cancelled') continue;
        final childName = ('${d.childFirstName} ${d.childLastName}').trim();
        final subtitle = childName.isNotEmpty
            ? (d.trainerName != null && d.trainerName!.isNotEmpty
                  ? '$childName · ${d.trainerName}'
                  : childName)
            : d.trainerName;
        add(
          CalendarActivity(
            id: 'demo:${d.id}',
            category: CalendarActivityCategory.demo,
            date: day,
            title: d.workshopTitle,
            startTime: d.startTime,
            endTime: d.endTime,
            subtitle: subtitle,
            workshopType: d.workshopType,
          ),
        );
      }

      // ── Afterschool (green) ──────────────────────────────────────
      // Build a `(program_id, YYYY-MM-DD) → session` index once from
      // the bulk result. For each date in range we iterate programs
      // (small set — handful of afterschool programs) and emit:
      //   • materialised row (with isClosed) if the index hit, OR
      //   • synthetic row from `AfterschoolProgram.isEligibleDay`
      //     when the server has not materialised the day yet
      //     (future dates — brief forbids any write to generate them).
      final sessionsByKey = <String, dynamic>{};
      for (final s in afsSessions) {
        final k = '${s.programId}:${_fmtDate(s.sessionDate)}';
        sessionsByKey[k] = s;
      }

      for (
        var cursor = DateTime(key.from.year, key.from.month, key.from.day);
        !cursor.isAfter(DateTime(key.to.year, key.to.month, key.to.day));
        cursor = cursor.add(const Duration(days: 1))
      ) {
        for (final p in programs) {
          if (!p.isEligibleDay(cursor)) continue;
          final k = '${p.id}:${_fmtDate(cursor)}';
          final session = sessionsByKey[k];
          final String activityId;
          String? subtitle = p.name;
          if (session != null) {
            activityId = 'afterschool-session:${session.id}';
            if (session.isClosed == true) {
              subtitle = '${p.name} · închis';
            }
          } else {
            activityId = 'afterschool:${p.id}:${_fmtDate(cursor)}';
          }
          add(
            CalendarActivity(
              id: activityId,
              category: CalendarActivityCategory.afterschool,
              date: cursor,
              title: 'Afterschool',
              startTime: p.startTime,
              endTime: p.endTime,
              subtitle: subtitle,
              workshopType: null,
            ),
          );
        }
      }

      // Chronological ordering per day.
      for (final list in out.values) {
        list.sort(CalendarActivity.compareByTime);
      }
      return out;
    });

String _fmtDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
