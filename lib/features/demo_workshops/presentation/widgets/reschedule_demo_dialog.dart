import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../children/presentation/widgets/child_form_helpers.dart';
import '../../../dashboard/providers/dashboard_providers.dart';
import '../../domain/demo_workshop.dart';
import '../../providers/demo_workshops_providers.dart';

/// Reschedule contract: **INSERT a new demo row** carrying the
/// original's child/parent/workshop/trainer, with a new date/time.
/// The original row is left untouched so the historical appointment
/// stays visible in "Istoric" — this is the explicit requirement
/// (lineage over mutation).
///
/// Returns the new demo id on success, `null` on cancel/error.
///
/// Duplicate-click protection: the primary button is disabled while
/// `_saving`, and the dialog pops once the INSERT returns an id so a
/// re-tap cannot double-fire.
Future<String?> showRescheduleDemoDialog({
  required BuildContext context,
  required WidgetRef ref,
  required DemoWorkshop original,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _RescheduleDialog(original: original),
  );
}

class _RescheduleDialog extends ConsumerStatefulWidget {
  const _RescheduleDialog({required this.original});
  final DemoWorkshop original;

  @override
  ConsumerState<_RescheduleDialog> createState() => _RescheduleDialogState();
}

class _RescheduleDialogState extends ConsumerState<_RescheduleDialog> {
  late DateTime _date = _today();
  late TimeOfDay _start = _parse(widget.original.startTime);
  late TimeOfDay _end =
      _parse(widget.original.endTime.isEmpty ? '11:00' : widget.original.endTime);
  bool _saving = false;
  String? _error;

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static TimeOfDay _parse(String hhmm) {
    final parts = hhmm.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 10,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:00';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _pickTime(bool start) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
    );
    if (picked != null) {
      setState(() => start ? _start = picked : _end = picked);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final userId = ref.read(currentUserProvider)?.id ?? '';
    try {
      final newId = await ref
          .read(demoWorkshopsRepositoryProvider)
          .reschedule(
            original: widget.original,
            newDate: _date,
            newStartTime: _fmtTime(_start),
            newEndTime: _fmtTime(_end),
            createdBy: userId,
          );
      // Reschedule is a strict INSERT — the original row is NOT
      // touched, so its tab stays valid. Only the NEW row's bucket
      // (upcoming / today / history, picked from _date) needs to
      // refetch. Dashboard count follows the new row too. Was 5
      // providers; now 1-2 + dashboardStats. Realtime handles the
      // cross-device fan-out.
      invalidateDemoBucketForDate(ref, _date);
      ref.invalidate(dashboardStatsProvider);
      if (mounted) Navigator.of(context).pop(newId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Eroare la reprogramare: $e';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inputDeco = buildChildFormInputDeco(theme);

    return AlertDialog(
      title: Text('Reprogramează · ${widget.original.childFullName}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Appointment-ul original rămâne în istoric. '
              'Se creează un demo nou cu aceleași date, dar la data '
              'și ora selectate mai jos.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 16),
            ChildFormField(
              label: 'Data nouă',
              required: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: inputDeco,
                  child: Row(children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 16, color: theme.colorScheme.outline),
                    const SizedBox(width: 8),
                    Text(formatDate(_date)),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(builder: (context, box) {
              final wide = box.maxWidth >= 320;
              final start = ChildFormField(
                label: 'Ora start',
                required: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _pickTime(true),
                  child: InputDecorator(
                    decoration: inputDeco,
                    child: Text(_start.format(context)),
                  ),
                ),
              );
              final end = ChildFormField(
                label: 'Ora final',
                required: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _pickTime(false),
                  child: InputDecorator(
                    decoration: inputDeco,
                    child: Text(_end.format(context)),
                  ),
                ),
              );
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: start),
                    const SizedBox(width: 12),
                    Expanded(child: end),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [start, const SizedBox(height: 12), end],
              );
            }),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed:
                _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Anulează')),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.event_repeat),
          label: const Text('Creează demo nou'),
        ),
      ],
    );
  }
}
