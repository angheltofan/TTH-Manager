import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import 'attendance_status_badge.dart';

// ── Column layout constants ───────────────────────────────────────────────────
const double _kCircleColWidth = 48;
const double _kStatusColWidth = 82;
const int _kFlexZi = 2;
const int _kFlexData = 2;
const int _kFlexInterval = 2;
const int _kFlexAtelier = 3;

/// Header row for the attendance table. Place above [AttendanceRowItem] list.
class AttendanceTableHeader extends StatelessWidget {
  const AttendanceTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.outline,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              SizedBox(
                  width: _kCircleColWidth,
                  child: Text('Ședința', style: style)),
              Expanded(flex: _kFlexZi, child: Text('Zi', style: style)),
              Expanded(flex: _kFlexData, child: Text('Data', style: style)),
              Expanded(
                  flex: _kFlexInterval,
                  child: Text('Interval orar', style: style)),
              Expanded(
                  flex: _kFlexAtelier,
                  child: Text('Atelier', style: style)),
              SizedBox(
                width: _kStatusColWidth,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text('Status', style: style),
                ),
              ),
            ],
          ),
        ),
        Divider(
            height: 1,
            thickness: 1,
            color: Theme.of(context)
                .colorScheme
                .outline
                .withValues(alpha: 0.12)),
      ],
    );
  }
}

/// A single table-style attendance row.
/// [index] is 1-based (1, 2, 3 …).
class AttendanceRowItem extends StatelessWidget {
  const AttendanceRowItem({
    super.key,
    required this.index,
    required this.workshopTitle,
    this.dayOfWeek,
    this.workshopDate,
    this.startTime,
    this.endTime,
    this.attendanceStatus,
    this.observation,
  });

  final int index;
  final String workshopTitle;
  final String? dayOfWeek;
  final DateTime? workshopDate;
  final String? startTime;
  final String? endTime;
  final String? attendanceStatus;
  final String? observation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLabel =
        workshopDate != null ? formatDate(workshopDate!) : '—';
    final timeLabel = (startTime != null && endTime != null)
        ? '${formatTimeString(startTime!)} – ${formatTimeString(endTime!)}'
        : '—';
    final dayLabel = dayOfWeek ?? '—';

    // Circle fill logic
    final Color circleColor;
    final Color circleText;
    final bool filled;
    switch (attendanceStatus) {
      case 'present':
        circleColor = AppColors.purple;
        circleText = Colors.white;
        filled = true;
      case 'absent':
        circleColor = const Color(0xFFEF4444);
        circleText = Colors.white;
        filled = true;
      case 'motivated':
        circleColor = const Color(0xFFF59E0B);
        circleText = Colors.white;
        filled = true;
      default:
        circleColor = theme.colorScheme.outline.withValues(alpha: 0.45);
        circleText = theme.colorScheme.outline;
        filled = false;
    }

    final cellStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurface,
      fontSize: 12,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Session number circle
              SizedBox(
                width: _kCircleColWidth,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? circleColor : Colors.transparent,
                    border: filled
                        ? null
                        : Border.all(color: circleColor, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$index',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: circleText,
                    ),
                  ),
                ),
              ),
              Expanded(
                  flex: _kFlexZi, child: Text(dayLabel, style: cellStyle)),
              Expanded(
                  flex: _kFlexData,
                  child: Text(dateLabel, style: cellStyle)),
              Expanded(
                  flex: _kFlexInterval,
                  child: Text(timeLabel, style: cellStyle)),
              Expanded(
                flex: _kFlexAtelier,
                child: Text(workshopTitle,
                    style: cellStyle,
                    overflow: TextOverflow.ellipsis),
              ),
              SizedBox(
                width: _kStatusColWidth,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: AttendanceStatusBadge(status: attendanceStatus),
                ),
              ),
            ],
          ),
          if (observation != null && observation!.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(left: _kCircleColWidth, top: 2),
              child: Text(
                observation!,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.outline,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
