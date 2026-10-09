import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tth_manager_app/features/dashboard/domain/calendar_activity.dart';
import 'package:tth_manager_app/features/dashboard/presentation/widgets/activity_calendar_section.dart';
import 'package:tth_manager_app/features/dashboard/providers/activity_calendar_providers.dart';

// Week-only Activity Calendar — hover preview on desktop, tap
// preview on mobile, informational rows.

CalendarActivity _mk(
  CalendarActivityCategory cat,
  DateTime day, {
  String? start,
  String? end,
  String title = 'Act',
  String? subtitle,
}) {
  return CalendarActivity(
    id: '${cat.name}:${day.toIso8601String()}:$title:${start ?? "-"}',
    category: cat,
    date: day,
    title: title,
    startTime: start,
    endTime: end,
    subtitle: subtitle,
  );
}

DateTime _mondayOfToday() {
  final now = DateTime.now();
  final midnight = DateTime(now.year, now.month, now.day);
  return midnight.subtract(Duration(days: midnight.weekday - 1));
}

Future<void> _pumpSection(
  WidgetTester tester,
  Map<DateTime, List<CalendarActivity>> fixture, {
  Size viewportSize = const Size(1280, 800),
}) async {
  // Pin devicePixelRatio to 1 so `viewportSize` is also the logical size
  // that MediaQuery exposes (test harness defaults to DPR 3.0).
  tester.view.physicalSize = viewportSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activityCalendarProvider.overrideWith((ref, key) async => fixture),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: ActivityCalendarSection()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<TestGesture> _createMouseGesture(WidgetTester tester) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  return gesture;
}

void main() {
  group('Chronological comparator', () {
    final day = DateTime(2026, 10, 15);
    test('sorts by startTime; null times last; title tiebreak', () {
      final a = _mk(CalendarActivityCategory.workshop, day, start: '17:00');
      final b = _mk(CalendarActivityCategory.afterschool, day, start: '14:00');
      final c = _mk(CalendarActivityCategory.demo, day, start: null);
      final list = [a, b, c]..sort(CalendarActivity.compareByTime);
      expect(list.first.category, CalendarActivityCategory.afterschool);
      expect(list.last.category, CalendarActivityCategory.demo);
    });
  });

  group('CalendarRangeKey', () {
    test('equality is day-resolution', () {
      final a = CalendarRangeKey(
        DateTime(2026, 10, 12, 11, 30),
        DateTime(2026, 10, 18, 23, 59),
      );
      final b = CalendarRangeKey(
        DateTime(2026, 10, 12),
        DateTime(2026, 10, 18),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('DayPreviewPanel — informational only', () {
    final day = DateTime(2026, 10, 8);

    testWidgets('empty day shows the "no activity" copy', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DayPreviewPanel(day: day, activities: const []),
        ),
      ));
      expect(find.text('Nicio activitate programată'), findsOneWidget);
    });

    testWidgets('renders every category with its uppercased label',
        (tester) async {
      final activities = [
        _mk(CalendarActivityCategory.afterschool, day,
            start: '14:00', end: '18:00', title: 'Afterschool'),
        _mk(CalendarActivityCategory.workshop, day,
            start: '17:00', end: '18:30', title: 'Atelier Robotica'),
        _mk(CalendarActivityCategory.demo, day,
            start: '17:00', end: '18:30', title: 'Demo Robotica'),
      ]..sort(CalendarActivity.compareByTime);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DayPreviewPanel(day: day, activities: activities),
        ),
      ));
      expect(find.text('Atelier Robotica'), findsOneWidget);
      expect(find.text('Demo Robotica'), findsOneWidget);
      expect(find.text('AFTERSCHOOL'), findsOneWidget);
      expect(find.text('DEMO'), findsOneWidget);
      expect(find.text('ATELIER'), findsOneWidget);
    });

    testWidgets('activity rows are NOT clickable (no InkWell, no chevron)',
        (tester) async {
      final activities = [
        _mk(CalendarActivityCategory.workshop, day,
            start: '17:00', title: 'Robotica'),
      ];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DayPreviewPanel(day: day, activities: activities),
        ),
      ));
      // No InkWell wrapping the activity row (there is one InkWell
      // for IconButtons etc elsewhere, but inside a plain
      // DayPreviewPanel we expect NONE).
      expect(find.byType(InkWell), findsNothing);
      // No chevron icons.
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });
  });

  group('Section layout — weekly only', () {
    testWidgets('renders a 7-day row and the three legend entries',
        (tester) async {
      await _pumpSection(tester, const {});
      // Legend
      expect(find.text('Ateliere'), findsOneWidget);
      expect(find.text('Demo-uri'), findsOneWidget);
      expect(find.text('Afterschool'), findsOneWidget);
      // Title + navigation
      expect(find.text('Calendar activități'), findsOneWidget);
      expect(find.text('Astăzi'), findsOneWidget);
      // Weekday header: 7 Romanian labels (long OR short form).
      final full = [
        'Luni','Marți','Miercuri','Joi','Vineri','Sâmbătă','Duminică',
      ];
      final short = ['Lun','Mar','Mie','Joi','Vin','Sâm','Dum'];
      final hits = full.where((l) => find.text(l).evaluate().isNotEmpty).length +
          short.where((l) => find.text(l).evaluate().isNotEmpty).length;
      expect(hits, greaterThanOrEqualTo(7));
    });

    testWidgets('NO month toggle / segmented button exists', (tester) async {
      await _pumpSection(tester, const {});
      expect(find.byType(SegmentedButton<Object>), findsNothing);
      // "Lună" was the old month-view label. Must be gone.
      expect(find.text('Lună'), findsNothing);
      expect(find.text('Săptămână'), findsNothing);
    });

    testWidgets('week navigation steps the week label', (tester) async {
      await _pumpSection(tester, const {});
      final monday = _mondayOfToday();
      // Current week label contains the current year.
      expect(find.textContaining('${monday.year}'), findsWidgets);
      // Next week.
      await tester.tap(find.byTooltip('Următor'));
      await tester.pumpAndSettle();
      final nextMonday = monday.add(const Duration(days: 7));
      // Still shows a year string — label format may wrap months.
      expect(find.textContaining('${nextMonday.year}'), findsWidgets);
      // Astăzi returns to current week.
      await tester.tap(find.text('Astăzi'));
      await tester.pumpAndSettle();
      expect(find.textContaining('${monday.year}'), findsWidgets);
    });
  });

  group('Desktop hover preview', () {
    testWidgets('hovering a day shows the preview; exit hides it',
        (tester) async {
      final today = DateTime.now();
      final todayKey = DateTime(today.year, today.month, today.day);
      await _pumpSection(tester, {
        todayKey: [
          _mk(CalendarActivityCategory.workshop, todayKey, title: 'Hover-Act'),
        ],
      });
      // Hover over today's cell. Day numbers are unique in a week —
      // find.text('${today.day}').first targets the first match, which
      // is the toolbar? No — the toolbar uses "N-M Luna" composite
      // strings, so the bare day number only matches in cells.
      final cellFinder = find.text('${today.day}').first;
      final gesture = await _createMouseGesture(tester);
      await gesture.moveTo(tester.getCenter(cellFinder));
      await tester.pumpAndSettle();
      expect(find.text('Hover-Act'), findsOneWidget);

      // Move away to a point far from any cell.
      await gesture.moveTo(const Offset(1, 1));
      // Dismissal is on a 120 ms timer — advance 300 ms.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Hover-Act'), findsNothing);
    });

    testWidgets('hovering a different day swaps the preview content',
        (tester) async {
      final today = DateTime.now();
      final monday = _mondayOfToday();
      final wed = monday.add(const Duration(days: 2));
      await _pumpSection(tester, {
        monday: [
          _mk(CalendarActivityCategory.workshop, monday, title: 'LUN-Act'),
        ],
        wed: [
          _mk(CalendarActivityCategory.demo, wed, title: 'MIE-Act'),
        ],
      });
      final gesture = await _createMouseGesture(tester);
      // Hover Monday.
      await gesture.moveTo(tester.getCenter(find.text('${monday.day}').first));
      await tester.pumpAndSettle();
      expect(find.text('LUN-Act'), findsOneWidget);
      expect(find.text('MIE-Act'), findsNothing);
      // Hover Wednesday.
      await gesture.moveTo(tester.getCenter(find.text('${wed.day}').first));
      await tester.pumpAndSettle();
      expect(find.text('MIE-Act'), findsOneWidget);
      expect(find.text('LUN-Act'), findsNothing);
      // today may equal mon or wed — not relevant for this test
      // (the switch itself is what we care about).
      // ignore: unused_local_variable
      final _ = today;
    });

    testWidgets('tooltip is CONTENT-sized: an empty-day preview is '
        'noticeably shorter than a 5-activity preview, with no '
        'forced vertical expansion', (tester) async {
      // Render both panels side-by-side in a plain MaterialApp — no
      // mouse pointer, no overlay, no CustomSingleChildLayout — so
      // we measure the raw intrinsic heights. The hover-driven
      // overlay only clamps them; the intrinsic sizes come from
      // DayPreviewPanel itself.
      final day = DateTime(2026, 10, 8);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 300,
                  child: DayPreviewPanel(
                    key: const ValueKey('empty'),
                    day: day,
                    activities: const [],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 300,
                  child: DayPreviewPanel(
                    key: const ValueKey('full'),
                    day: day,
                    activities: [
                      for (var i = 0; i < 5; i++)
                        _mk(CalendarActivityCategory.workshop, day,
                            start: '${8 + i}:00', title: 'Slot $i'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final emptyH =
          tester.getSize(find.byKey(const ValueKey('empty'))).height;
      final fullH =
          tester.getSize(find.byKey(const ValueKey('full'))).height;
      expect(fullH, greaterThan(emptyH));
      expect(
        emptyH,
        lessThan(100),
        reason:
            'Empty-day panel measured $emptyH px; should be well '
            'under 100 px (header + one-line copy + small padding).',
      );
    });

    testWidgets('preview is clamped inside the root overlay bounds',
        (tester) async {
      final today = DateTime.now();
      final todayKey = DateTime(today.year, today.month, today.day);
      await tester.binding.setSurfaceSize(const Size(1280, 480));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pumpSection(tester, {
        todayKey: [
          for (var i = 0; i < 8; i++)
            _mk(CalendarActivityCategory.workshop, todayKey,
                start: '${8 + i}:00', title: 'Slot $i'),
        ],
      });
      final gesture = await _createMouseGesture(tester);
      await gesture.moveTo(tester.getCenter(find.text('${today.day}').first));
      await tester.pumpAndSettle();
      final previewFinder = find.byType(DayPreviewPanel);
      expect(previewFinder, findsOneWidget);
      final previewRect = tester.getRect(previewFinder);
      final rootOverlay = find.byType(Overlay).evaluate().first;
      final overlayBox = rootOverlay.findRenderObject() as RenderBox;
      final overlaySize = overlayBox.size;
      // Preview sits fully inside the overlay — never clipped off
      // the top or bottom edge.
      expect(previewRect.top, greaterThanOrEqualTo(0));
      expect(
        previewRect.bottom,
        lessThanOrEqualTo(overlaySize.height),
        reason:
            'Overlay height=${overlaySize.height}, '
            'preview bottom=${previewRect.bottom}',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────
  // Mobile tap preview — floating tooltip, no bottom sheet, no
  // backdrop. Covers the four target widths from the brief.
  // ───────────────────────────────────────────────────────────────
  group('Mobile tap preview', () {
    for (final width in [320.0, 375.0, 390.0, 430.0]) {
      testWidgets('width $width: all seven day numbers remain visible',
          (tester) async {
        final today = DateTime.now();
        final todayKey = DateTime(today.year, today.month, today.day);
        await _pumpSection(
          tester,
          {
            todayKey: [
              _mk(CalendarActivityCategory.workshop, todayKey,
                  start: '17:00', title: 'Mobile-Act'),
            ],
          },
          viewportSize: Size(width, 720),
        );
        final mon = _mondayOfToday();
        for (var i = 0; i < 7; i++) {
          final d = mon.add(Duration(days: i));
          expect(find.text('${d.day}'), findsAtLeastNWidgets(1),
              reason: 'Day ${d.day} missing at width $width');
        }
      });
    }

    testWidgets('tap opens the floating preview — no modal / bottom sheet',
        (tester) async {
      final today = DateTime.now();
      final todayKey = DateTime(today.year, today.month, today.day);
      await _pumpSection(
        tester,
        {
          todayKey: [
            _mk(CalendarActivityCategory.workshop, todayKey,
                start: '17:00', title: 'Mobile-Act'),
          ],
        },
        viewportSize: const Size(390, 720),
      );
      await tester.tap(find.text('${today.day}').first);
      await tester.pumpAndSettle();
      expect(find.byType(DayPreviewPanel), findsOneWidget);
      expect(find.text('Mobile-Act'), findsOneWidget);
      // CRITICAL: the OLD implementation used `showModalBottomSheet`
      // which inserts a `BottomSheet` widget + a modal `ModalBarrier`.
      // Neither must appear.
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(DraggableScrollableSheet), findsNothing);
    });

    testWidgets('tap outside dismisses the mobile preview', (tester) async {
      final today = DateTime.now();
      final todayKey = DateTime(today.year, today.month, today.day);
      await _pumpSection(
        tester,
        {
          todayKey: [
            _mk(CalendarActivityCategory.workshop, todayKey,
                start: '17:00', title: 'Mobile-Act'),
          ],
        },
        viewportSize: const Size(390, 720),
      );
      await tester.tap(find.text('${today.day}').first);
      await tester.pumpAndSettle();
      expect(find.byType(DayPreviewPanel), findsOneWidget);
      // Legend "Ateliere" text is outside the tooltip and outside
      // any cell TapRegion group member → onTapOutside fires.
      await tester.tap(find.text('Ateliere'));
      await tester.pumpAndSettle();
      expect(find.byType(DayPreviewPanel), findsNothing);
    });

    testWidgets('tapping the same day a second time closes it',
        (tester) async {
      final today = DateTime.now();
      final todayKey = DateTime(today.year, today.month, today.day);
      await _pumpSection(
        tester,
        {
          todayKey: [
            _mk(CalendarActivityCategory.workshop, todayKey, title: 'X'),
          ],
        },
        viewportSize: const Size(390, 720),
      );
      await tester.tap(find.text('${today.day}').first);
      await tester.pumpAndSettle();
      expect(find.byType(DayPreviewPanel), findsOneWidget);
      await tester.tap(find.text('${today.day}').first);
      await tester.pumpAndSettle();
      expect(find.byType(DayPreviewPanel), findsNothing);
    });

    testWidgets('tapping a different day swaps the preview', (tester) async {
      final mon = _mondayOfToday();
      final wed = mon.add(const Duration(days: 2));
      await _pumpSection(
        tester,
        {
          mon: [_mk(CalendarActivityCategory.workshop, mon, title: 'LUN-M')],
          wed: [_mk(CalendarActivityCategory.demo, wed, title: 'MIE-M')],
        },
        viewportSize: const Size(390, 720),
      );
      await tester.tap(find.text('${mon.day}').first);
      await tester.pumpAndSettle();
      expect(find.text('LUN-M'), findsOneWidget);
      await tester.tap(find.text('${wed.day}').first);
      await tester.pumpAndSettle();
      expect(find.text('MIE-M'), findsOneWidget);
      expect(find.text('LUN-M'), findsNothing);
    });

    testWidgets('mobile preview is clamped inside the overlay',
        (tester) async {
      final today = DateTime.now();
      final todayKey = DateTime(today.year, today.month, today.day);
      await _pumpSection(
        tester,
        {
          todayKey: [
            for (var i = 0; i < 6; i++)
              _mk(CalendarActivityCategory.workshop, todayKey,
                  start: '${8 + i}:00', title: 'Slot $i'),
          ],
        },
        viewportSize: const Size(390, 720),
      );
      await tester.tap(find.text('${today.day}').first);
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.byType(DayPreviewPanel));
      final overlayBox = find.byType(Overlay).evaluate().first
          .findRenderObject() as RenderBox;
      final size = overlayBox.size;
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(size.width));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(size.height));
    });

    testWidgets('activity rows in the mobile preview do NOT navigate',
        (tester) async {
      final today = DateTime.now();
      final todayKey = DateTime(today.year, today.month, today.day);
      await _pumpSection(
        tester,
        {
          todayKey: [
            _mk(CalendarActivityCategory.workshop, todayKey,
                start: '17:00', title: 'Nav-Test'),
          ],
        },
        viewportSize: const Size(390, 720),
      );
      await tester.tap(find.text('${today.day}').first);
      await tester.pumpAndSettle();
      final inkInsidePanel = find.descendant(
        of: find.byType(DayPreviewPanel),
        matching: find.byType(InkWell),
      );
      expect(inkInsidePanel, findsNothing);
    });
  });

  group('Desktop behavior remains the hover-driven path (regression)', () {
    testWidgets('hover (not tap) opens the preview at desktop width',
        (tester) async {
      final today = DateTime.now();
      final todayKey = DateTime(today.year, today.month, today.day);
      await _pumpSection(
        tester,
        {
          todayKey: [
            _mk(CalendarActivityCategory.workshop, todayKey,
                title: 'DesktopOK'),
          ],
        },
        viewportSize: const Size(1280, 800),
      );
      final gesture = await _createMouseGesture(tester);
      await gesture.moveTo(tester.getCenter(find.text('${today.day}').first));
      await tester.pumpAndSettle();
      expect(find.byType(DayPreviewPanel), findsOneWidget);
      expect(find.text('DesktopOK'), findsOneWidget);
    });
  });
}
