import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../children/presentation/widgets/child_form_helpers.dart';
import '../../domain/afterschool_enrollment.dart';
import '../../domain/afterschool_program.dart';
import '../../providers/afterschool_providers.dart';
import 'weekday_multi_selector.dart';

/// Edit an enrollment's schedule / arrival time. Admin-only.
/// Custom monthly fee is intentionally NOT edited here — financial
/// management for Afterschool happens exclusively in the child
/// profile, next to the payment history.
/// The three fields are independent — the dialog lets an admin change
/// any subset without re-entering the whole row.
Future<void> showEditEnrollmentDialog({
  required BuildContext context,
  required WidgetRef ref,
  required AfterschoolProgram program,
  required AfterschoolEnrollment enrollment,
  required String childName,
}) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => _EditDialog(
      program: program,
      enrollment: enrollment,
      childName: childName,
    ),
  );
}

class _EditDialog extends ConsumerStatefulWidget {
  const _EditDialog({
    required this.program,
    required this.enrollment,
    required this.childName,
  });
  final AfterschoolProgram program;
  final AfterschoolEnrollment enrollment;
  final String childName;

  @override
  ConsumerState<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends ConsumerState<_EditDialog> {
  late bool _followsAllDays;
  late Set<int> _pickedDays;
  TimeOfDay? _arrival;
  bool _saving = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    final e = widget.enrollment;
    _followsAllDays = e.attendanceDays == null;
    _pickedDays = {...(e.attendanceDays ?? widget.program.daysOfWeek)};
    if (e.expectedArrivalTime != null) {
      _arrival = _parseTod(e.expectedArrivalTime!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text('Editează înscrierea · ${widget.childName}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 500),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ChildFormField(
                label: 'Zile participare',
                required: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(
                        'Toate zilele programului '
                        '(${formatIsoWeekdaysShort(widget.program.daysOfWeek)})',
                        style: theme.textTheme.bodyMedium,
                      ),
                      value: _followsAllDays,
                      onChanged: (v) => setState(() {
                        _followsAllDays = v;
                        if (v) {
                          _pickedDays = {...widget.program.daysOfWeek};
                        }
                      }),
                    ),
                    if (!_followsAllDays) ...[
                      const SizedBox(height: 4),
                      WeekdayMultiSelector(
                        selected: _pickedDays,
                        allowed: widget.program.daysOfWeek,
                        onChanged: (next) =>
                            setState(() => _pickedDays = next),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ChildFormField(
                label: 'Ora estimată de sosire (opțional)',
                child: Row(children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        final picked = await showTimePicker(
                            context: context,
                            initialTime: _arrival ??
                                const TimeOfDay(hour: 14, minute: 0));
                        if (picked != null) {
                          setState(() => _arrival = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: buildChildFormInputDeco(theme).copyWith(
                            hintText: 'Alege ora (opțional)'),
                        child: Row(children: [
                          Icon(Icons.access_time,
                              size: 16,
                              color: theme.colorScheme.outline),
                          const SizedBox(width: 8),
                          Text(_arrival == null
                              ? 'Fără oră'
                              : _fmtTod(_arrival!)),
                        ]),
                      ),
                    ),
                  ),
                  if (_arrival != null)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() => _arrival = null),
                      tooltip: 'Șterge ora',
                    ),
                ]),
              ),
              if (_err != null) ...[
                const SizedBox(height: 10),
                Text(_err!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Renunță')),
        FilledButton.icon(
          style:
              FilledButton.styleFrom(backgroundColor: AppColors.purple),
          icon: _saving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save_outlined),
          label: const Text('Salvează'),
          onPressed: _saving ? null : _onSave,
        ),
      ],
    );
  }

  Future<void> _onSave() async {
    if (!_followsAllDays && _pickedDays.isEmpty) {
      setState(() =>
          _err = 'Selectează cel puțin o zi sau bifează "Toate zilele".');
      return;
    }
    final profile = ref.read(currentProfileProvider).valueOrNull;
    final adminId = profile?.id;
    if (adminId == null) return;

    setState(() {
      _saving = true;
      _err = null;
    });
    try {
      final repo = ref.read(afterschoolEnrollmentsRepositoryProvider);
      final e = widget.enrollment;

      // Diff each field vs. current and issue only the calls needed.
      final wantsDays = _followsAllDays ? null : _pickedDays;
      final currentDays = e.attendanceDays;
      final daysChanged = wantsDays == null
          ? currentDays != null
          : currentDays == null ||
              currentDays.length != wantsDays.length ||
              !currentDays.containsAll(wantsDays);
      if (daysChanged) {
        await repo.updateAttendanceDays(
            isAdmin: true,
            enrollmentId: e.id,
            attendanceDays: wantsDays);
      }

      final wantsArrival = _arrival == null ? null : _fmtTod(_arrival!);
      final currentArrival = e.expectedArrivalTime;
      final arrivalChanged =
          _normalizeTime(wantsArrival) != _normalizeTime(currentArrival);
      if (arrivalChanged) {
        await repo.updateExpectedArrivalTime(
            isAdmin: true,
            enrollmentId: e.id,
            expectedArrivalTime: wantsArrival);
      }

      // Custom fee is intentionally NOT edited from the operational
      // dialog — financial changes happen in the child profile where
      // they are visible alongside the payment history. The DB column
      // `custom_monthly_fee` stays as-is on the enrollment row.

      // Full invalidation surface — see enroll_child_dialog._onSave().
      // attendance_days changes shift the weekday-filtered expected
      // list, so both the day summary and the roster families must
      // refresh locally, not only via realtime.
      ref.invalidate(afterschoolActiveEnrollmentsForProgramProvider(
          widget.program.id));
      ref.invalidate(afterschoolAllActiveEnrollmentsProvider);
      ref.invalidate(afterschoolRosterForDateProvider);
      ref.invalidate(afterschoolExpectedEnrollmentsForDateProvider);
      ref.invalidate(afterschoolDaySummaryProvider);
      ref.invalidate(
          afterschoolEnrollmentsForChildProvider(e.childId));
      ref.invalidate(afterschoolMonthAttendanceProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Înscriere actualizată')));
    } catch (e) {
      setState(() {
        _saving = false;
        _err = _prettyError(e.toString());
      });
    }
  }
}

String _fmtTod(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

TimeOfDay _parseTod(String hhmmss) {
  final parts = hhmmss.split(':');
  return TimeOfDay(
    hour: int.tryParse(parts[0]) ?? 0,
    minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
  );
}

/// Normalize a time string for equality comparison ("13:00" == "13:00:00").
String? _normalizeTime(String? t) {
  if (t == null) return null;
  final parts = t.split(':');
  if (parts.length < 2) return t;
  return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
}

String _prettyError(String raw) {
  if (raw.contains('attendance_days_not_subset_of_program_days')) {
    return 'Zilele selectate nu se încadrează în zilele programului. '
        'Poate cineva a modificat programul — deschide din nou dialogul.';
  }
  if (raw.contains('insufficient_privileges')) {
    return 'Doar administratorii pot edita înscrieri.';
  }
  return raw;
}
