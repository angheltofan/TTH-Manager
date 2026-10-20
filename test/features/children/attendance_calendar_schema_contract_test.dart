import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Regression: PostgrestException "column afterschool_sessions.status
// does not exist" (42703) after commit 4cdbc6b. The afterschool
// extension in AttendanceCalendarRepository.fetchMonth selected a
// `status` column that doesn't exist on `afterschool_sessions`
// (session-level state is `is_closed` + `closed_reason`; per-child
// status lives on afterschool_attendance.status).
//
// These are static-contract tests over the repository source file.
// Full-stack verification (REST → PostgREST → prod) requires a staff
// token this harness doesn't carry, so we lock the SELECT shape
// against the known prod schema in-repo so a regression this cheap
// is impossible to reintroduce.
//
// If future migrations LEGITIMATELY add a `status` column to
// `afterschool_sessions` (and we want to read it), update both the
// repo AND this test together.

const _repoPath =
    'lib/features/children/data/attendance_calendar_repository.dart';

String _readSelectBlockFor(String table, String src) {
  // Grab everything between `.from('<table>')` and the subsequent
  // `.gte(` / `.inFilter(` / `.eq(` / `)`-at-end-of-chain. We only
  // need the SELECT argument shape for the assertion.
  final idx = src.indexOf(".from('$table')");
  if (idx < 0) return '';
  final rest = src.substring(idx);
  // Pull the first `.select(...)` call that follows.
  final selIdx = rest.indexOf('.select(');
  if (selIdx < 0) return '';
  // Walk balanced parens.
  final start = selIdx + '.select('.length;
  var depth = 1;
  var i = start;
  while (i < rest.length && depth > 0) {
    final c = rest[i];
    if (c == '(') depth++;
    if (c == ')') depth--;
    i++;
  }
  return rest.substring(start, i - 1);
}

void main() {
  late String source;

  setUpAll(() {
    source = File(_repoPath).readAsStringSync();
  });

  group('afterschool_sessions SELECT shape (prod schema contract)', () {
    test('the SELECT MUST NOT reference "status" (that column does '
        'not exist on afterschool_sessions in prod — bug fix 2026-10-20)',
        () {
      final selectBlock =
          _readSelectBlockFor('afterschool_sessions', source);
      expect(selectBlock, isNotEmpty,
          reason: 'repo must still query afterschool_sessions');
      // The column list is a single comma-separated string literal in
      // the Dart source. We strip whitespace / concatenation markers
      // and check for a standalone `status` or `, status,` /
      // `status,` / `, status` / trailing `status`.
      final flat =
          selectBlock.replaceAll(RegExp(r'''['"\n\s]'''), '');
      // Make sure we don't match substrings of OTHER valid columns
      // (e.g. a hypothetical `status_at`). Walk comma-separated.
      final cols = flat.split(',');
      for (final c in cols) {
        expect(c, isNot(equals('status')),
            reason:
                'afterschool_sessions has NO `status` column — day-level '
                'state is `is_closed` + `closed_reason`; per-child '
                'status lives on afterschool_attendance.status');
      }
    });

    test('the SELECT MUST include session-level start_time + end_time '
        '(they live on afterschool_sessions, not on the program)',
        () {
      final selectBlock =
          _readSelectBlockFor('afterschool_sessions', source);
      final flat =
          selectBlock.replaceAll(RegExp(r'''['"\n\s]'''), '');
      final cols = flat.split(',');
      expect(cols, contains('start_time'));
      expect(cols, contains('end_time'));
    });

    test('the SELECT MUST include is_closed (so the UI can distinguish '
        'a closed day from a normal day)', () {
      final selectBlock =
          _readSelectBlockFor('afterschool_sessions', source);
      final flat =
          selectBlock.replaceAll(RegExp(r'''['"\n\s]'''), '');
      expect(flat.split(','), contains('is_closed'));
    });
  });

  group('afterschool_attendance SELECT + UPSERT shape', () {
    test('attendance SELECT uses CORRECT columns + no `is_archived` '
        '(afterschool schema has no such column)', () {
      final selectBlock =
          _readSelectBlockFor('afterschool_attendance', source);
      expect(selectBlock, isNotEmpty);
      // We must list session_id + child_id + status + observation +
      // marked_at + marked_by to render the editor + authorship pill.
      final flat =
          selectBlock.replaceAll(RegExp(r'''['"\n\s]'''), '');
      final cols = flat
          .split(',')
          // profiles!marked_by(...) is an embedded resource; keep its
          // leading token out of the simple-column assertion.
          .where((c) => !c.contains('('))
          .toList();
      expect(cols, containsAll(const [
        'id',
        'session_id',
        'child_id',
        'status',
        'observation',
        'marked_at',
        'marked_by',
      ]));
      // Negative: `afterschool_attendance` does NOT have is_archived
      // (unlike workshop `attendance`). If the SELECT ever adds it,
      // PostgREST will 400 on the response.
      expect(cols, isNot(contains('is_archived')));
    });

    test('UPSERT payload keys match the prod columns exactly', () {
      // The call site writes an inline map literal, so we assert the
      // string contains the specific key tokens and no stray ones.
      expect(source, contains("'session_id': afterschoolSessionId"));
      expect(source, contains("'child_id': childId"));
      expect(source, contains("'status': status"));
      expect(source, contains("'observation': observation"));
      expect(source, contains("'marked_by': markedBy"));
      expect(source, contains("'marked_at':"));
      // No `is_archived` — that column is workshop-only.
      expect(
          source,
          isNot(contains(
              RegExp(r"'is_archived'\s*:\s*false[\s\S]*afterschool"))),
          reason: 'afterschool_attendance has no is_archived column');
      // Conflict key MUST be the UNIQUE (session_id, child_id) pair.
      expect(source, contains("onConflict: 'session_id,child_id'"));
    });

    test('status writes only accept "present" / "absent" (DB CHECK)',
        () {
      // Programmatic guard inside the repo must reject anything else
      // before the DB round-trip.
      expect(source, contains("if (status != 'present' && status != 'absent')"));
    });
  });

  group('generate_afterschool_sessions_window RPC', () {
    test('RPC call uses the correct parameter names', () {
      expect(source,
          contains(RegExp(r"rpc\(\s*'generate_afterschool_sessions_window'")));
      expect(source, contains("'p_program_id'"));
      expect(source, contains("'p_from'"));
      expect(source, contains("'p_to'"));
    });

    test('RPC errors are swallowed (parent tokens, out-of-window)', () {
      // The repo wraps the RPC in try / catch (_) so a 403 from a
      // parent token or a 0-insert out-of-window run never blocks
      // the subsequent SELECT.
      expect(
          source,
          contains(RegExp(
              r"rpc\(\s*'generate_afterschool_sessions_window'[\s\S]*?catch\s*\(_\)")));
    });
  });
}
