import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/responsive.dart';
import 'attendance_status_badge.dart';

// ── Column layout constants (desktop table) ───────────────────────────────────
const double _kCircleColWidth = 48;
const double _kStatusColWidth = 82;
const int _kFlexZi = 2;
const int _kFlexData = 2;
const int _kFlexInterval = 2;
const int _kFlexAtelier = 3;

/// Header row for the attendance table.  Only rendered on desktop/tablet.
class AttendanceTableHeader extends StatelessWidget {
  const AttendanceTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    // On mobile the cards render without a header row.
    if (context.isMobile) return const SizedBox.shrink();

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

/// A single attendance row.
///
/// * On **mobile** it renders a compact vertical card (Ședința → info lines).
/// * On **desktop/tablet** it renders the classic horizontal table row.
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

  // ── shared helpers ──────────────────────────────────────────────────────────

  ({Color circleColor, Color circleText, bool filled}) _circleStyle() {
    switch (attendanceStatus) {
      case 'present':
        return (
          circleColor: AppColors.purple,
          circleText: Colors.white,
          filled: true
        );
      case 'absent':
        return (
          circleColor: const Color(0xFFEF4444),
          circleText: Colors.white,
          filled: true
        );
      case 'motivated':
        return (
          circleColor: const Color(0xFFF59E0B),
          circleText: Colors.white,
          filled: true
        );
      default:
        return (
          circleColor: const Color(0xFF94A3B8),
          circleText: const Color(0xFF94A3B8),
          filled: false
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (context.isMobile) return _MobileCard(row: this);
    return _DesktopRow(row: this);
  }
}

// ── Mobile card ───────────────────────────────────────────────────────────────

class _MobileCard extends StatelessWidget {
  const _MobileCard({required this.row});
  final AttendanceRowItem row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = row._circleStyle();
    final dateLabel =
        row.workshopDate != null ? formatDate(row.workshopDate!) : '—';
    final timeLabel = (row.startTime != null && row.endTime != null)
        ? '${formatTimeString(row.startTime!)} – ${formatTimeString(row.endTime!)}'
        : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Session number circle
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(top: 2, right: 10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.filled ? cs.circleColor : Colors.transparent,
              border: cs.filled
                  ? null
                  : Border.all(color: cs.circleColor, width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(
              '${row.index}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: cs.circleText,
              ),
            ),
          ),
          // Info column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ședința #${row.index}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                _InfoLine(
                    icon: Icons.calendar_today_outlined,
                    text: row.dayOfWeek != null
                        ? '${row.dayOfWeek}, $dateLabel'
                        : dateLabel),
                _InfoLine(
                    icon: Icons.access_time_rounded, text: timeLabel),
                _InfoLine(
                    icon: Icons.sports_outlined, text: row.workshopTitle),
                if (row.observation != null && row.observation!.isNotEmpty)
                  _InfoLine(
                      icon: Icons.notes_rounded,
                      text: row.observation!,
                      italic: true),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AttendanceStatusBadge(status: row.attendanceStatus),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text, this.italic = false});
  final IconData icon;
  final String text;
  final bool italic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: 12, color: theme.colorScheme.outline),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
                fontStyle: italic ? FontStyle.italic : FontStyle.normal,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Desktop table row ─────────────────────────────────────────────────────────

class _DesktopRow extends StatelessWidget {
  const _DesktopRow({required this.row});
  final AttendanceRowItem row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = row._circleStyle();
    final dateLabel =
        row.workshopDate != null ? formatDate(row.workshopDate!) : '—';
    final timeLabel = (row.startTime != null && row.endTime != null)
        ? '${formatTimeString(row.startTime!)} – ${formatTimeString(row.endTime!)}'
        : '—';
    final dayLabel = row.dayOfWeek ?? '—';

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
              SizedBox(
                width: _kCircleColWidth,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.filled ? cs.circleColor : Colors.transparent,
                    border: cs.filled
                        ? null
                        : Border.all(color: cs.circleColor, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${row.index}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: cs.circleText,
                    ),
                  ),
                ),
              ),
              Expanded(
                  flex: _kFlexZi,
                  child: Text(dayLabel, style: cellStyle)),
              Expanded(
                  flex: _kFlexData,
                  child: Text(dateLabel, style: cellStyle)),
              Expanded(
                  flex: _kFlexInterval,
                  child: Text(timeLabel, style: cellStyle)),
              Expanded(
                flex: _kFlexAtelier,
                child: Text(row.workshopTitle,
                    style: cellStyle,
                    overflow: TextOverflow.ellipsis),
              ),
              SizedBox(
                width: _kStatusColWidth,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: AttendanceStatusBadge(status: row.attendanceStatus),
                ),
              ),
            ],
          ),
          if (row.observation != null && row.observation!.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(left: _kCircleColWidth, top: 2),
              child: Text(
                row.observation!,
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
