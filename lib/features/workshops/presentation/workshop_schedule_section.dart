import 'package:flutter/material.dart';

import 'workshop_basic_info_section.dart';

// ── Schedule section (date + start time + end time) ───────────────────────────

class WorkshopScheduleSection extends StatelessWidget {
  const WorkshopScheduleSection({
    super.key,
    required this.workshopDate,
    required this.startTime,
    required this.endTime,
    required this.onPickDate,
    required this.onPickStart,
    required this.onPickEnd,
    required this.isWide,
  });

  final DateTime? workshopDate;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final VoidCallback onPickDate;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final dateField = WorkshopFormField(
      label: 'Data',
      required: true,
      child: GestureDetector(
        onTap: onPickDate,
        child: AbsorbPointer(
          child: TextFormField(
            readOnly: true,
            decoration: workshopInputDecoration(theme).copyWith(
              hintText: 'Alege data',
              suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
            ),
            controller: TextEditingController(
              text: workshopDate == null ? '' : _fmtDate(workshopDate!),
            ),
          ),
        ),
      ),
    );

    final startField = _timeTile(theme,
        label: 'Ora start', time: startTime, onTap: onPickStart);
    final endField = _timeTile(theme,
        label: 'Ora final', time: endTime, onTap: onPickEnd);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        dateField,
        const SizedBox(height: 16),
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: startField),
              const SizedBox(width: 16),
              Expanded(child: endField),
            ],
          )
        else ...[
          startField,
          const SizedBox(height: 16),
          endField,
        ],
      ],
    );
  }

  Widget _timeTile(
    ThemeData theme, {
    required String label,
    required TimeOfDay? time,
    required VoidCallback onTap,
  }) =>
      WorkshopFormField(
        label: label,
        required: true,
        child: GestureDetector(
          onTap: onTap,
          child: AbsorbPointer(
            child: TextFormField(
              readOnly: true,
              decoration: workshopInputDecoration(theme).copyWith(
                hintText: 'HH:MM',
                suffixIcon:
                    const Icon(Icons.access_time_rounded, size: 18),
              ),
              controller: TextEditingController(
                text: time == null ? '' : _fmt(time),
              ),
            ),
          ),
        ),
      );

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  static String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
