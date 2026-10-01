import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/utils/weekday_utils.dart';
import '../../afterschool/providers/afterschool_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../../trainers/providers/trainers_providers.dart';
import '../data/child_attendance_repository.dart';
import '../data/children_repository.dart';
import '../domain/child_row.dart';

// ── Repository ───────────────────────────────────────────────────────────────

final childrenRepositoryProvider = Provider<ChildrenRepository>((ref) {
  return ChildrenRepository(ref.watch(supabaseClientProvider));
});

final childAttendanceRepositoryProvider =
    Provider<ChildAttendanceRepository>((ref) {
  return ChildAttendanceRepository(ref.watch(supabaseClientProvider));
});

// ── Full list with workshops + attendance (role-aware) ───────────────────────

final allChildrenProvider = FutureProvider<List<ChildRow>>((ref) {
  final repo = ref.watch(childrenRepositoryProvider);
  return repo.getAllWithWorkshops();
});

// ── Filter / pagination state ─────────────────────────────────────────────────

final childrenSearchProvider = StateProvider<String>((ref) => '');

/// 'active' = active only (default), 'inactive' = inactive only, null = all.
///
/// Defaults to 'active' so the children page hides archived rows from the
/// default operational view. Users opt into inactives via the Status dropdown
/// in [ChildrenFilterBar].
final childrenActiveFilterProvider = StateProvider<String?>((ref) => 'active');

/// workshop id to filter by, or null for all
final childrenWorkshopFilterProvider = StateProvider<String?>((ref) => null);

/// trainer id to filter by, or null for all
final childrenTrainerFilterProvider = StateProvider<String?>((ref) => null);

final childrenPageProvider = StateProvider<int>((ref) => 0);
final childrenPageSizeProvider = StateProvider<int>((ref) => 10);

// ── Derived: filtered list ───────────────────────────────────────────────────

final filteredChildrenProvider =
    Provider<AsyncValue<List<ChildRow>>>((ref) {
  final allAsync = ref.watch(allChildrenProvider);
  final search = ref.watch(childrenSearchProvider).trim().toLowerCase();
  final activeFilter = ref.watch(childrenActiveFilterProvider);
  final workshopFilter = ref.watch(childrenWorkshopFilterProvider);
  final trainerFilter = ref.watch(childrenTrainerFilterProvider);

  // Afterschool enrollments feed the "Programe" filter together with
  // workshop series. One flat list, grouped by child_id.
  final afsEnrollments =
      ref.watch(afterschoolAllActiveEnrollmentsProvider).valueOrNull ??
          const [];
  final afsPrograms =
      ref.watch(afterschoolAllProgramsProvider).valueOrNull ?? const [];
  final afsProgramNameById = {for (final p in afsPrograms) p.id: p.name};
  final afsNamesByChild = <String, Set<String>>{};
  for (final e in afsEnrollments) {
    final name = afsProgramNameById[e.programId];
    if (name == null) continue;
    afsNamesByChild.putIfAbsent(e.childId, () => <String>{}).add(name);
  }

  return allAsync.whenData((list) {
    final filtered = list.where((c) {
      if (search.isNotEmpty) {
        final nameMatch = c.fullName.toLowerCase().contains(search);
        final parentMatch =
            c.parentName?.toLowerCase().contains(search) ?? false;
        if (!nameMatch && !parentMatch) return false;
      }
      if (activeFilter == 'active' && c.isActive != true) return false;
      if (activeFilter == 'inactive' && c.isActive == true) return false;
      if (workshopFilter != null) {
        final inWorkshops =
            c.workshops.any((w) => w.title == workshopFilter);
        final inAfterschool =
            (afsNamesByChild[c.id] ?? const <String>{}).contains(workshopFilter);
        if (!inWorkshops && !inAfterschool) return false;
      }
      if (trainerFilter != null &&
          !c.workshops.any((w) => w.trainerId == trainerFilter)) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
    return filtered;
  });
});

// ── Derived: unique programs for filter dropdown ─────────────────────────────
//
// Workshop series titles (sorted by weekday order) + Afterschool program
// names. Both participate in the "Toate programele" filter so a child
// enrolled only in Afterschool still shows up when filtered by that
// program. The dropdown value equals the display label.
final childrenWorkshopOptionsProvider =
    Provider<List<MapEntry<String, String>>>((ref) {
  final list = ref.watch(allChildrenProvider).valueOrNull ?? [];

  // Collect the first-seen dayOfWeek + startTime for each unique title so we
  // can sort by real week order instead of alphabetically.
  final titleMeta = <String, ({String day, String time})>{};
  for (final c in list) {
    for (final w in c.workshops) {
      titleMeta.putIfAbsent(
        w.title,
        () => (day: w.dayOfWeek, time: w.startTime),
      );
    }
  }

  final titles = titleMeta.keys.toList()
    ..sort((a, b) {
      final ma = titleMeta[a]!;
      final mb = titleMeta[b]!;
      return compareByWeekday(
        dayA: ma.day,
        dayB: mb.day,
        timeA: ma.time,
        timeB: mb.time,
        titleA: a,
        titleB: b,
      );
    });

  final workshopEntries = titles.map((t) => MapEntry(t, t)).toList();

  // Append Afterschool program names, alphabetically, deduplicated and
  // excluding any name that already matches a workshop series (never
  // happens in practice but defensive).
  final existing = workshopEntries.map((e) => e.key).toSet();
  final afsPrograms =
      ref.watch(afterschoolAllProgramsProvider).valueOrNull ?? const [];
  final afsNames = afsPrograms
      .map((p) => p.name)
      .where((n) => !existing.contains(n))
      .toSet()
      .toList()
    ..sort();
  final afsEntries = afsNames.map((n) => MapEntry(n, n)).toList();

  return [...workshopEntries, ...afsEntries];
});

// ── Derived: trainer list for filter dropdown ─────────────────────────────────

final childrenTrainersProvider =
    Provider<List<MapEntry<String, String>>>((ref) {
  final trainers = ref.watch(trainersListProvider).valueOrNull ?? [];
  return trainers
      .map((t) => MapEntry(t.id, t.fullName))
      .toList()
    ..sort((a, b) => a.value.compareTo(b.value));
});

// ── Weekly attendances (present status only, Mon–Sun current week) ───────────

final weeklyAttendancesProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(childrenRepositoryProvider);
  final now = DateTime.now();
  final monday =
      DateTime(now.year, now.month, now.day - (now.weekday - 1));
  final sunday = monday.add(const Duration(days: 6));
  final from = monday.toIso8601String().substring(0, 10);
  final to = sunday.toIso8601String().substring(0, 10);

  return repo.countWeeklyPresentAttendances(from: from, to: to);
});

// ── Legacy providers (kept for child edit form) ───────────────────────────────

final childDetailProvider = FutureProvider.family<Child?, String>((ref, id) {
  return ref.watch(childrenRepositoryProvider).getById(id);
});

final childAttendanceHistoryProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, childId) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final repo = ref.read(childAttendanceRepositoryProvider);
  if (profile?.isTrainer ?? false) {
    return repo.getAttendanceHistoryForTrainerFull(childId, profile!.id);
  }
  return repo.getAttendanceHistoryFull(childId);
});

// Legacy providers (childActivityHistoryProvider, childActivityLimit,
// childCurrentCycleSummaryProvider, childCurrentCycleActivityProvider)
// removed 2026-08-22 alongside the underlying views. Card / list
// widgets now aggregate directly from base tables via
// childCurrentStatusRowsProvider + childPaymentCyclesNewProvider.

