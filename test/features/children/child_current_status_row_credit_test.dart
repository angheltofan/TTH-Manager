import 'package:flutter_test/flutter_test.dart';

import 'package:tth_manager_app/features/children/domain/child_current_status_row.dart';

void main() {
  group('ChildCurrentStatusRow.billingSeriesId', () {
    test('falls back to seriesId when credited is null', () {
      const r = ChildCurrentStatusRow(
        childId: 'c1',
        seriesId: 's-tue',
      );
      expect(r.billingSeriesId, 's-tue');
      expect(r.creditedSeriesId, isNull);
    });

    test('prefers creditedSeriesId when set', () {
      const r = ChildCurrentStatusRow(
        childId: 'c1',
        seriesId: 's-tue',
        creditedSeriesId: 's-mon',
      );
      // billingSeriesId is the one that OWNS the financial timeline;
      // snapshot grouping uses THIS, not the physical series.
      expect(r.billingSeriesId, 's-mon');
    });

    test('billingSeriesId is null when both series are null', () {
      const r = ChildCurrentStatusRow(childId: 'c1');
      expect(r.billingSeriesId, isNull);
    });

    test('fromMap round-trips credited_series_id', () {
      final r = ChildCurrentStatusRow.fromMap({
        'child_id': 'c1',
        'attendance_id': 'a1',
        'credited_series_id': 's-tue',
      });
      expect(r.creditedSeriesId, 's-tue');
    });

    test('fromMap tolerates missing credited_series_id', () {
      final r = ChildCurrentStatusRow.fromMap({
        'child_id': 'c1',
        'attendance_id': 'a1',
      });
      expect(r.creditedSeriesId, isNull);
    });
  });
}
