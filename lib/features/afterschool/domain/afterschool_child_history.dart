import 'afterschool_enrollment.dart';
import 'afterschool_program.dart';

/// One history entry for the "Istoric cicluri" tab, Afterschool side —
/// attendance-only. A row exists for every (program, year, month) that
/// falls inside the child's enrollment coverage for that program. No
/// payment / fee data is attached: Afterschool is a non-paid product
/// on the child profile.
class AfterschoolChildHistoryEntry {
  const AfterschoolChildHistoryEntry({
    required this.year,
    required this.month,
  });

  final int year;
  final int month;
}

class AfterschoolChildHistoryBlock {
  const AfterschoolChildHistoryBlock({
    required this.program,
    required this.entries,
  });

  final AfterschoolProgram program;
  final List<AfterschoolChildHistoryEntry> entries;
}

/// Pure builder — groups the child's attendance history by program,
/// iterating each (year, month) covered by at least one of the child's
/// enrollments in that program.
///
/// Rules:
///   • Months STRICTLY after `today`'s current month are excluded —
///     history represents past/current, nu viitor.
///   • Months STRICTLY before every enrollment's `enrolled_from` sunt
///     excluse. Months STRICTLY after every enrollment's
///     `enrolled_until` (when set) sunt excluse.
///   • Blocurile sunt sortate alfabetic după numele programului;
///     intrările în interiorul unui bloc sunt newest-first.
///   • Un program fără niciun enrollment covering sau fără entries
///     este omis.
List<AfterschoolChildHistoryBlock> buildAfterschoolChildHistory({
  required List<AfterschoolEnrollment> enrollments,
  required List<AfterschoolProgram> allPrograms,
  required DateTime today,
}) {
  if (enrollments.isEmpty) return const [];

  final normalisedToday = DateTime(today.year, today.month, today.day);
  final currentYm = normalisedToday.year * 12 + normalisedToday.month;

  final programsById = {for (final p in allPrograms) p.id: p};
  final enrolmentsByProgram = <String, List<AfterschoolEnrollment>>{};
  for (final e in enrollments) {
    enrolmentsByProgram.putIfAbsent(e.programId, () => []).add(e);
  }

  final blocks = <AfterschoolChildHistoryBlock>[];
  for (final entry in enrolmentsByProgram.entries) {
    final program = programsById[entry.key];
    if (program == null) continue;
    final enrols = entry.value;

    DateTime? earliestStart;
    DateTime? latestEnd;
    var openEnded = false;
    for (final e in enrols) {
      final from = DateTime(e.enrolledFrom.year, e.enrolledFrom.month, 1);
      if (earliestStart == null || from.isBefore(earliestStart)) {
        earliestStart = from;
      }
      final until = e.enrolledUntil;
      if (until == null) {
        openEnded = true;
      } else {
        final end = DateTime(until.year, until.month, 1);
        if (latestEnd == null || end.isAfter(latestEnd)) {
          latestEnd = end;
        }
      }
    }
    if (earliestStart == null) continue;

    DateTime rightEdge;
    if (openEnded) {
      rightEdge = DateTime(normalisedToday.year, normalisedToday.month, 1);
    } else {
      final end = latestEnd!;
      rightEdge = end.year * 12 + end.month > currentYm
          ? DateTime(normalisedToday.year, normalisedToday.month, 1)
          : end;
    }

    final rows = <AfterschoolChildHistoryEntry>[];
    var cursorY = earliestStart.year;
    var cursorM = earliestStart.month;
    while (cursorY < rightEdge.year ||
        (cursorY == rightEdge.year && cursorM <= rightEdge.month)) {
      final covered = enrols.any((e) => e.coversMonth(cursorY, cursorM));
      final cursorYm = cursorY * 12 + cursorM;
      final isFuture = cursorYm > currentYm;
      if (covered && !isFuture) {
        rows.add(AfterschoolChildHistoryEntry(
          year: cursorY,
          month: cursorM,
        ));
      }
      cursorM++;
      if (cursorM > 12) {
        cursorM = 1;
        cursorY++;
      }
    }

    if (rows.isEmpty) continue;
    rows.sort((a, b) {
      final ay = a.year * 100 + a.month;
      final by = b.year * 100 + b.month;
      return by.compareTo(ay);
    });
    blocks.add(AfterschoolChildHistoryBlock(
      program: program,
      entries: rows,
    ));
  }

  blocks.sort((a, b) => a.program.name.compareTo(b.program.name));
  return blocks;
}
