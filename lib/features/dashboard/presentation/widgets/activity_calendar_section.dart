import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/section_card.dart';
import '../../domain/calendar_activity.dart';
import '../../providers/activity_calendar_providers.dart';

/// Dashboard "Calendar activități" — weekly, 7 columns, Mon → Sun.
///
/// Desktop: hovering a day cell shows a floating informational
/// preview above the cell (flipped below when there's no room
/// above). The preview is temporary; it closes 120 ms after the
/// pointer leaves both the cell and the preview.
///
/// Mobile: tapping a day opens a drag-handle bottom sheet with the
/// same `DayPreviewPanel`. Rows are informational — they do not
/// navigate anywhere.
class ActivityCalendarSection extends ConsumerStatefulWidget {
  const ActivityCalendarSection({super.key});

  @override
  ConsumerState<ActivityCalendarSection> createState() =>
      _ActivityCalendarSectionState();
}

class _ActivityCalendarSectionState
    extends ConsumerState<ActivityCalendarSection> {
  late DateTime _mondayAnchor;

  /// One GlobalKey per weekday column (0..6). Reused across week
  /// navigation — only the keyed cell's content (date, activities)
  /// changes. The key gives us the cell's RenderBox so the overlay
  /// can measure viewport-relative placement.
  final List<GlobalKey> _cellKeys = List.generate(7, (_) => GlobalKey());

  OverlayEntry? _overlayEntry;
  DateTime? _previewDay;
  Timer? _hoverCloseTimer;
  bool _pointerInPreview = false;
  ScrollableState? _scrollable;

  @override
  void initState() {
    super.initState();
    _mondayAnchor = _mondayOf(DateTime.now());
  }

  @override
  void dispose() {
    _dismissPreview(immediate: true);
    super.dispose();
  }

  // ── Range math ──────────────────────────────────────────────────

  static DateTime _mondayOf(DateTime d) =>
      DateTime(d.year, d.month, d.day - (d.weekday - 1));

  DateTime get _rangeFrom => _mondayAnchor;
  DateTime get _rangeTo => _mondayAnchor.add(const Duration(days: 6));

  void _goToday() {
    _dismissPreview(immediate: true);
    setState(() => _mondayAnchor = _mondayOf(DateTime.now()));
  }

  void _step(int sign) {
    _dismissPreview(immediate: true);
    setState(() {
      _mondayAnchor = _mondayAnchor.add(Duration(days: 7 * sign));
    });
  }

  // ── Hover + tap handlers ────────────────────────────────────────

  void _onCellEnter(
    DateTime day,
    Map<DateTime, List<CalendarActivity>> byDay,
  ) {
    _hoverCloseTimer?.cancel();
    _hoverCloseTimer = null;
    if (_previewDay == day) return;
    _showPreview(day, byDay);
  }

  void _onCellExit() {
    // Short dismissal timer bridges the small gap between a cell and
    // its hover-triggered popover (~120 ms is enough for the pointer
    // to re-enter the preview region without a flicker).
    _hoverCloseTimer?.cancel();
    _hoverCloseTimer = Timer(const Duration(milliseconds: 120), () {
      if (!_pointerInPreview) _dismissPreview();
    });
  }

  void _onPreviewEnter() {
    _pointerInPreview = true;
    _hoverCloseTimer?.cancel();
    _hoverCloseTimer = null;
  }

  void _onPreviewExit() {
    _pointerInPreview = false;
    _hoverCloseTimer?.cancel();
    _hoverCloseTimer = Timer(
      const Duration(milliseconds: 120),
      _dismissPreview,
    );
  }

  void _onCellTapMobile(
    DateTime day,
    Map<DateTime, List<CalendarActivity>> byDay,
  ) {
    final items = byDay[day] ?? const <CalendarActivity>[];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.8,
          ),
          child: DayPreviewPanel(day: day, activities: items),
        ),
      ),
    );
  }

  // ── Preview overlay (desktop) ───────────────────────────────────

  void _showPreview(
    DateTime day,
    Map<DateTime, List<CalendarActivity>> byDay,
  ) {
    _dismissPreview(immediate: true);
    _previewDay = day;
    final items = byDay[day] ?? const <CalendarActivity>[];
    final entry = OverlayEntry(
      builder: (ctx) => _HoverPreviewLayer(
        day: day,
        activities: items,
        cellKey: _cellKeys[day.difference(_mondayAnchor).inDays],
        onEnter: _onPreviewEnter,
        onExit: _onPreviewExit,
      ),
    );
    final overlay = Overlay.of(context, rootOverlay: true);
    overlay.insert(entry);
    _overlayEntry = entry;
    // Dismiss on dashboard scroll so the floating preview can't drift
    // off-screen.
    _scrollable = Scrollable.maybeOf(context);
    _scrollable?.position.addListener(_onDashboardScroll);
  }

  void _onDashboardScroll() => _dismissPreview(immediate: true);

  void _dismissPreview({bool immediate = false}) {
    _hoverCloseTimer?.cancel();
    _hoverCloseTimer = null;
    if (immediate) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      _previewDay = null;
      _pointerInPreview = false;
      _scrollable?.position.removeListener(_onDashboardScroll);
      _scrollable = null;
      return;
    }
    if (_overlayEntry == null) return;
    _overlayEntry!.remove();
    _overlayEntry = null;
    _previewDay = null;
    _pointerInPreview = false;
    _scrollable?.position.removeListener(_onDashboardScroll);
    _scrollable = null;
  }

  // ── Build ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final key = CalendarRangeKey(_rangeFrom, _rangeTo);
    final activitiesAsync = ref.watch(activityCalendarProvider(key));
    final isMobile = context.isMobile;

    return SectionCard(
      title: 'Calendar activități',
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Ateliere, demo-uri și afterschool',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          _CalendarToolbar(
            anchor: _mondayAnchor,
            onToday: _goToday,
            onPrev: () => _step(-1),
            onNext: () => _step(1),
          ),
          const SizedBox(height: 12),
          activitiesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: AppError(
                message: 'Nu am putut încărca activitățile: $e',
              ),
            ),
            data: (byDay) => _WeekRow(
              monday: _mondayAnchor,
              byDay: byDay,
              cellKeys: _cellKeys,
              isMobile: isMobile,
              onCellEnter: (d) => _onCellEnter(d, byDay),
              onCellExit: _onCellExit,
              onCellTapMobile: (d) => _onCellTapMobile(d, byDay),
            ),
          ),
          const SizedBox(height: 12),
          const _CalendarLegend(),
        ],
      ),
    );
  }
}

// ── Toolbar ──────────────────────────────────────────────────────────

class _CalendarToolbar extends StatelessWidget {
  const _CalendarToolbar({
    required this.anchor,
    required this.onToday,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime anchor;
  final VoidCallback onToday;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = _weekLabel(anchor);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.purple,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Precedent',
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        TextButton(onPressed: onToday, child: const Text('Astăzi')),
        IconButton(
          tooltip: 'Următor',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

const List<String> _roMonths = [
  '',
  'Ianuarie', 'Februarie', 'Martie', 'Aprilie', 'Mai', 'Iunie',
  'Iulie', 'August', 'Septembrie', 'Octombrie', 'Noiembrie', 'Decembrie',
];

const List<String> _roMonthsShort = [
  '',
  'ian', 'feb', 'mar', 'apr', 'mai', 'iun',
  'iul', 'aug', 'sep', 'oct', 'noi', 'dec',
];

const List<String> _roWeekdaysFull = [
  '',
  'Luni', 'Marți', 'Miercuri', 'Joi', 'Vineri', 'Sâmbătă', 'Duminică',
];
const List<String> _roWeekdaysShort = [
  '',
  'Lun', 'Mar', 'Mie', 'Joi', 'Vin', 'Sâm', 'Dum',
];

String _weekLabel(DateTime monday) {
  final sunday = monday.add(const Duration(days: 6));
  if (monday.month == sunday.month) {
    return '${monday.day}–${sunday.day} ${_roMonths[monday.month]} ${monday.year}';
  }
  return '${monday.day} ${_roMonthsShort[monday.month]}'
      ' – ${sunday.day} ${_roMonthsShort[sunday.month]} ${sunday.year}';
}

// ── Week row + cells ─────────────────────────────────────────────────

class _WeekRow extends StatelessWidget {
  const _WeekRow({
    required this.monday,
    required this.byDay,
    required this.cellKeys,
    required this.isMobile,
    required this.onCellEnter,
    required this.onCellExit,
    required this.onCellTapMobile,
  });

  final DateTime monday;
  final Map<DateTime, List<CalendarActivity>> byDay;
  final List<GlobalKey> cellKeys;
  final bool isMobile;
  final ValueChanged<DateTime> onCellEnter;
  final VoidCallback onCellExit;
  final ValueChanged<DateTime> onCellTapMobile;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    return Column(
      children: [
        _WeekdayHeader(),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (ctx, constraints) {
            final cellWidth = constraints.maxWidth / 7;
            const cellHeight = 92.0;
            return SizedBox(
              height: cellHeight,
              child: Row(
                children: [
                  for (var c = 0; c < 7; c++)
                    SizedBox(
                      width: cellWidth,
                      height: cellHeight,
                      child: _CalendarCell(
                        key: cellKeys[c],
                        day: monday.add(Duration(days: c)),
                        isToday: monday.add(Duration(days: c)) == todayKey,
                        activities:
                            byDay[monday.add(Duration(days: c))] ?? const [],
                        isMobile: isMobile,
                        onEnter: onCellEnter,
                        onExit: onCellExit,
                        onTapMobile: onCellTapMobile,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = context.isMobile;
    final labels = isMobile ? _roWeekdaysShort : _roWeekdaysFull;
    return Row(
      children: [
        for (var w = 1; w <= 7; w++)
          Expanded(
            child: Center(
              child: Text(
                labels[w],
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CalendarCell extends StatelessWidget {
  const _CalendarCell({
    super.key,
    required this.day,
    required this.isToday,
    required this.activities,
    required this.isMobile,
    required this.onEnter,
    required this.onExit,
    required this.onTapMobile,
  });

  final DateTime day;
  final bool isToday;
  final List<CalendarActivity> activities;
  final bool isMobile;
  final ValueChanged<DateTime> onEnter;
  final VoidCallback onExit;
  final ValueChanged<DateTime> onTapMobile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAny = activities.isNotEmpty;
    final border = theme.colorScheme.outline.withValues(alpha: 0.25);
    final bg = isToday
        ? AppColors.purple.withValues(alpha: 0.04)
        : Colors.transparent;
    final dayNumberColor = isToday
        ? AppColors.purple
        : theme.textTheme.bodyMedium?.color;
    final counts = _countsByCategory(activities);

    final cell = Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${day.day}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                    color: dayNumberColor,
                  ),
                ),
                const Spacer(),
                if (hasAny)
                  Text(
                    '${activities.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            const Spacer(),
            if (hasAny)
              Wrap(
                spacing: 3,
                runSpacing: 3,
                children: [
                  if (counts.workshop > 0)
                    _CategoryDot(
                      color: AppColors.purple,
                      count: counts.workshop,
                    ),
                  if (counts.demo > 0)
                    _CategoryDot(
                      color: AppColors.demoBadge,
                      count: counts.demo,
                    ),
                  if (counts.afterschool > 0)
                    _CategoryDot(
                      color: AppColors.success,
                      count: counts.afterschool,
                    ),
                ],
              ),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(2),
      child: isMobile
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTapMobile(day),
              child: cell,
            )
          : MouseRegion(
              cursor: SystemMouseCursors.basic,
              onEnter: (_) => onEnter(day),
              onExit: (_) => onExit(),
              child: cell,
            ),
    );
  }
}

class _Counts {
  _Counts(this.workshop, this.demo, this.afterschool);
  final int workshop;
  final int demo;
  final int afterschool;
}

_Counts _countsByCategory(List<CalendarActivity> xs) {
  var w = 0, d = 0, a = 0;
  for (final x in xs) {
    switch (x.category) {
      case CalendarActivityCategory.workshop:
        w++;
        break;
      case CalendarActivityCategory.demo:
        d++;
        break;
      case CalendarActivityCategory.afterschool:
        a++;
        break;
    }
  }
  return _Counts(w, d, a);
}

class _CategoryDot extends StatelessWidget {
  const _CategoryDot({required this.color, required this.count});
  final Color color;
  final int count;
  @override
  Widget build(BuildContext context) {
    if (count == 1) {
      return Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          height: 1.0,
        ),
      ),
    );
  }
}

// ── Legend ───────────────────────────────────────────────────────────

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      alignment: WrapAlignment.start,
      children: [
        _legendDot(AppColors.purple, 'Ateliere', theme),
        _legendDot(AppColors.demoBadge, 'Demo-uri', theme),
        _legendDot(AppColors.success, 'Afterschool', theme),
      ],
    );
  }

  Widget _legendDot(Color color, String label, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ── Hover preview layer (desktop) ────────────────────────────────────

/// A full-overlay layer that places the `DayPreviewPanel` as a
/// content-sized tooltip near the hovered cell. Uses
/// `CustomSingleChildLayout` so the delegate can read the measured
/// child size and position it with viewport-aware clamping; the
/// surrounding area of the overlay is a no-hit zone (the layout box
/// only hit-tests its own child), so pointer events over other
/// calendar cells still reach them.
class _HoverPreviewLayer extends StatelessWidget {
  const _HoverPreviewLayer({
    required this.day,
    required this.activities,
    required this.cellKey,
    required this.onEnter,
    required this.onExit,
  });

  final DateTime day;
  final List<CalendarActivity> activities;
  final GlobalKey cellKey;
  final VoidCallback onEnter;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final cellCtx = cellKey.currentContext;
    final cellBox = cellCtx?.findRenderObject() as RenderBox?;
    final overlayBox =
        Overlay.of(context, rootOverlay: true).context.findRenderObject()
            as RenderBox?;
    if (cellBox == null || overlayBox == null) {
      return const SizedBox.shrink();
    }
    final cellOrigin = cellBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    final cellRect = cellOrigin & cellBox.size;
    return Positioned.fill(
      child: CustomSingleChildLayout(
        delegate: _TooltipLayoutDelegate(cellRect: cellRect),
        child: MouseRegion(
          onEnter: (_) => onEnter(),
          onExit: (_) => onExit(),
          child: DayPreviewPanel(day: day, activities: activities),
        ),
      ),
    );
  }
}

/// Measurement-based placement. The child is told it can be up to
/// 300 px wide and up to the LARGER of (room above, room below) tall;
/// then the delegate reads the resulting child size and picks a
/// corner. If the tooltip fits above the cell, it opens upward
/// (preferred); otherwise it opens downward. Horizontal placement is
/// cell-centered and clamped to viewport edges.
class _TooltipLayoutDelegate extends SingleChildLayoutDelegate {
  _TooltipLayoutDelegate({required this.cellRect});
  final Rect cellRect;

  static const double _maxWidth = 300.0;
  static const double _margin = 12.0;
  static const double _gap = 6.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final roomAbove = (cellRect.top - _margin - _gap).clamp(0.0, double.infinity);
    final roomBelow =
        (constraints.maxHeight - cellRect.bottom - _margin - _gap)
            .clamp(0.0, double.infinity);
    final maxH = roomAbove > roomBelow ? roomAbove : roomBelow;
    return BoxConstraints(
      maxWidth: _maxWidth,
      maxHeight: maxH <= 0 ? constraints.maxHeight - 2 * _margin : maxH,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    // Horizontal: center on the cell, clamp to viewport edges.
    double left = cellRect.center.dx - childSize.width / 2;
    final maxLeft = size.width - _margin - childSize.width;
    if (maxLeft < _margin) {
      left = _margin;
    } else {
      left = left.clamp(_margin, maxLeft);
    }
    // Vertical: prefer above when the child fits above.
    final roomAbove = cellRect.top - _margin - _gap;
    final roomBelow = size.height - cellRect.bottom - _margin - _gap;
    final fitsAbove = childSize.height <= roomAbove;
    final fitsBelow = childSize.height <= roomBelow;
    double top;
    if (fitsAbove) {
      top = cellRect.top - _gap - childSize.height;
    } else if (fitsBelow) {
      top = cellRect.bottom + _gap;
    } else {
      // Doesn't fit cleanly in either direction (short viewport);
      // place in whichever side has more room with hard clamp.
      final preferAbove = roomAbove >= roomBelow;
      top = preferAbove
          ? _margin
          : (size.height - _margin - childSize.height);
    }
    final maxTop = size.height - _margin - childSize.height;
    if (maxTop < _margin) {
      top = _margin;
    } else {
      top = top.clamp(_margin, maxTop);
    }
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(_TooltipLayoutDelegate oldDelegate) =>
      oldDelegate.cellRect != cellRect;
}

// ── Day preview panel (public — used in tests + both platforms) ─────

/// Content-sized informational preview — no fixed height, no
/// Flexible, no Spacer. The parent's `BoxConstraints` cap the
/// maximum width/height (via `_TooltipLayoutDelegate`); within those
/// bounds the panel sizes itself to its content. When a day has an
/// unusually long schedule, the inner column spills into a
/// `SingleChildScrollView` that only kicks in once the max-height
/// is hit.
class DayPreviewPanel extends StatelessWidget {
  const DayPreviewPanel({
    super.key,
    required this.day,
    required this.activities,
  });

  final DateTime day;
  final List<CalendarActivity> activities;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final full =
        '${_roWeekdaysFull[day.weekday]}, ${day.day} ${_roMonths[day.month]} ${day.year}';
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          full,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.1,
            fontSize: 12.5,
          ),
        ),
        const SizedBox(height: 6),
        if (activities.isEmpty)
          Text(
            'Nicio activitate programată',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
              fontSize: 11.5,
            ),
          )
        else ...[
          for (var i = 0; i < activities.length; i++) ...[
            if (i > 0) const SizedBox(height: 5),
            _ActivityRow(activity: activities[i]),
          ],
        ],
      ],
    );
    return Material(
      elevation: 6,
      color: theme.cardTheme.color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.25),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        // Scrollable only when content exceeds the parent's max
        // height; sizes to content otherwise.
        child: SingleChildScrollView(child: content),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity});
  final CalendarActivity activity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (color, label, _) = _styleFor(activity.category);
    final timeLabel = _timeLabel(activity.startTime, activity.endTime);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: color, width: 2.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                timeLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  fontSize: 9.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 1),
          Text(
            activity.title,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (activity.subtitle != null && activity.subtitle!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                activity.subtitle!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  (Color, String, IconData) _styleFor(CalendarActivityCategory c) {
    switch (c) {
      case CalendarActivityCategory.workshop:
        return (AppColors.purple, 'Atelier', Icons.school_rounded);
      case CalendarActivityCategory.demo:
        return (AppColors.demoBadge, 'Demo', Icons.auto_awesome_rounded);
      case CalendarActivityCategory.afterschool:
        return (AppColors.success, 'Afterschool', Icons.local_cafe_rounded);
    }
  }
}

String _timeLabel(String? start, String? end) {
  final s = _fmtTime(start);
  final e = _fmtTime(end);
  if (s == null && e == null) return '—';
  if (s != null && e != null) return '$s–$e';
  return s ?? e!;
}

String? _fmtTime(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final parts = raw.split(':');
  if (parts.length < 2) return raw;
  return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
}
