import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

// Re-export the canonical workshop-type → (icon, color) mapping so
// every existing call site that does
//   `import '.../workshop_card_helpers.dart'`
// continues to see `workshopTypeStyle` without an import change.
// The function itself lives in `core/utils/workshop_type_style.dart`
// so non-dashboard features (e.g. the parent dashboard) can consume it
// without crossing a feature boundary.
export '../../../../core/utils/workshop_type_style.dart'
    show workshopTypeStyle;

// ── Workshop card status ──────────────────────────────────────────────────────

enum WorkshopCardStatus { upcoming, ongoing, finished }

TimeOfDay _parseHHMM(String t) {
  final p = t.split(':');
  return TimeOfDay(
    hour: int.tryParse(p[0]) ?? 0,
    minute: int.tryParse(p.length > 1 ? p[1] : '0') ?? 0,
  );
}

WorkshopCardStatus resolveWorkshopCardStatus({
  required DateTime workshopDate,
  required String startTime,
  required String endTime,
}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final wDay = DateTime(
      workshopDate.year, workshopDate.month, workshopDate.day);

  if (wDay.isAfter(today)) return WorkshopCardStatus.upcoming;
  if (wDay.isBefore(today)) return WorkshopCardStatus.finished;

  final tod = TimeOfDay.now();
  final s = _parseHHMM(startTime);
  final e = _parseHHMM(endTime);
  final nowM = tod.hour * 60 + tod.minute;
  final startM = s.hour * 60 + s.minute;
  final endM = e.hour * 60 + e.minute;

  if (nowM < startM) return WorkshopCardStatus.upcoming;
  if (nowM <= endM) return WorkshopCardStatus.ongoing;
  return WorkshopCardStatus.finished;
}

// ── Time block widget ─────────────────────────────────────────────────────────

class WorkshopTimeBlock extends StatelessWidget {
  const WorkshopTimeBlock({
    super.key,
    required this.startTime,
    required this.endTime,
    required this.timeColor,
  });

  final String startTime;
  final String endTime;
  final Color timeColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: timeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            startTime,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: timeColor,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          Container(
            width: 1,
            height: 10,
            margin: const EdgeInsets.symmetric(vertical: 2),
            color: timeColor.withValues(alpha: 0.25),
          ),
          Text(
            endTime,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: timeColor.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Meta chip ─────────────────────────────────────────────────────────────────

class WorkshopMetaChip extends StatelessWidget {
  const WorkshopMetaChip({
    super.key,
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}

// ── "Al meu" badge ────────────────────────────────────────────────────────────

class WorkshopOwnBadge extends StatelessWidget {
  const WorkshopOwnBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.purple.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Al meu',
        style: TextStyle(
          color: AppColors.purple,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
