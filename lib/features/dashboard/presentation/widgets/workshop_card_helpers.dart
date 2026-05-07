import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

// ── Workshop type style (icon + color) ────────────────────────────────────────

(IconData, Color) workshopTypeStyle(String type) {
  final t = type.toLowerCase();
  if (t.contains('robotic')) {
    return (Icons.precision_manufacturing_outlined, AppColors.info);
  }
  if (t.contains('lectur')) return (Icons.menu_book_outlined, AppColors.warning);
  if (t.contains('modela')) {
    return (Icons.view_in_ar_outlined, const Color(0xFF14B8A6));
  }
  if (t.contains('tales') || t.contains('povestiri')) {
    return (Icons.auto_stories_outlined, const Color(0xFFF97316));
  }
  if (t.contains('desen') || t.contains('pictur') || t.contains('culoare')) {
    return (Icons.draw_outlined, AppColors.purple);
  }
  return (Icons.event_outlined, AppColors.purple);
}

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
