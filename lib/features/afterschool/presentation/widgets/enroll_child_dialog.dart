import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../children/domain/child_row.dart';
import '../../../children/presentation/widgets/child_form_helpers.dart';
import '../../../children/providers/children_providers.dart';
import '../../domain/afterschool_program.dart';
import '../../providers/afterschool_providers.dart';
import 'weekday_multi_selector.dart';

/// Enroll a child in the given Afterschool program. Admin-only.
/// Warns explicitly when the program is at or over capacity, but does
/// not hard-block — the admin can proceed after acknowledging.
Future<void> showEnrollChildDialog({
  required BuildContext context,
  required WidgetRef ref,
  required AfterschoolProgram program,
  required int currentActiveCount,
}) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => _EnrollDialog(
      program: program,
      currentActiveCount: currentActiveCount,
    ),
  );
}

class _EnrollDialog extends ConsumerStatefulWidget {
  const _EnrollDialog({
    required this.program,
    required this.currentActiveCount,
  });
  final AfterschoolProgram program;
  final int currentActiveCount;

  @override
  ConsumerState<_EnrollDialog> createState() => _EnrollDialogState();
}

class _EnrollDialogState extends ConsumerState<_EnrollDialog> {
  final _formKey = GlobalKey<FormState>();
  ChildRow? _child;
  DateTime _enrolledFrom = _today();
  bool _followsAllDays = true;
  Set<int> _pickedDays = {};
  TimeOfDay? _arrival;
  final _feeCtrl = TextEditingController();
  bool _saving = false;
  String? _err;
  bool _acknowledgedCapacity = false;

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    _pickedDays = {...widget.program.daysOfWeek};
  }

  @override
  void dispose() {
    _feeCtrl.dispose();
    super.dispose();
  }

  bool get _atCapacity =>
      widget.program.maxCapacity != null &&
      widget.currentActiveCount >= widget.program.maxCapacity!;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final childrenAsync = ref.watch(allChildrenProvider);

    return AlertDialog(
      title: Text('Înscrie copil · ${widget.program.name}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_atCapacity) _capacityWarning(theme),
                if (_atCapacity) const SizedBox(height: 12),
                ChildFormField(
                  label: 'Copil',
                  required: true,
                  child: childrenAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Eroare: $e',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.error)),
                    data: (all) {
                      // active children only, alphabetical
                      final list = [
                        for (final c in all)
                          if (c.isActive == true) c
                      ]..sort((a, b) => a.fullName.compareTo(b.fullName));
                      return DropdownButtonFormField<ChildRow>(
                        initialValue: _child,
                        isExpanded: true,
                        decoration: buildChildFormInputDeco(theme),
                        items: [
                          for (final c in list)
                            DropdownMenuItem(
                                value: c, child: Text(c.fullName)),
                        ],
                        onChanged: (v) => setState(() => _child = v),
                        validator: (v) =>
                            v == null ? 'Selectează un copil' : null,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                ChildFormField(
                  label: 'Data începerii',
                  required: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2020, 1, 1),
                        lastDate: DateTime(2100, 12, 31),
                        initialDate: _enrolledFrom,
                      );
                      if (picked != null) {
                        setState(() => _enrolledFrom = DateTime(
                            picked.year, picked.month, picked.day));
                      }
                    },
                    child: InputDecorator(
                      decoration: buildChildFormInputDeco(theme),
                      child: Row(children: [
                        Icon(Icons.calendar_today,
                            size: 16, color: theme.colorScheme.outline),
                        const SizedBox(width: 8),
                        Text(
                            '${_enrolledFrom.day.toString().padLeft(2, '0')}.'
                            '${_enrolledFrom.month.toString().padLeft(2, '0')}.'
                            '${_enrolledFrom.year}'),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
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
                  child: _ArrivalPicker(
                    value: _arrival,
                    onChanged: (v) => setState(() => _arrival = v),
                  ),
                ),
                const SizedBox(height: 12),
                ChildFormField(
                  label: 'Tarif personalizat (opțional)',
                  child: TextFormField(
                    controller: _feeCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: buildChildFormInputDeco(theme).copyWith(
                      hintText:
                          'Lăsat gol → tariful standard (${_fmtFee(widget.program.monthlyFee)} ${widget.program.currency}/lună)',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final n = _parseNum(v);
                      if (n == null || n <= 0) return 'Tarif invalid';
                      return null;
                    },
                  ),
                ),
                if (_err != null) ...[
                  const SizedBox(height: 12),
                  Text(_err!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.error)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Renunță')),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.purple),
          icon: _saving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.person_add_alt_1),
          label: const Text('Înscrie'),
          onPressed: _saving ? null : _onSave,
        ),
      ],
    );
  }

  Widget _capacityWarning(ThemeData theme) {
    final max = widget.program.maxCapacity!;
    return InkWell(
      onTap: () => setState(
          () => _acknowledgedCapacity = !_acknowledgedCapacity),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.warning.withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Programul are deja ${widget.currentActiveCount} din $max '
              'locuri ocupate. Vrei să continui înscrierea?',
              style: theme.textTheme.bodySmall,
            ),
          ),
          Checkbox(
            value: _acknowledgedCapacity,
            onChanged: (v) => setState(
                () => _acknowledgedCapacity = v ?? false),
          ),
        ]),
      ),
    );
  }

  Future<void> _onSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_atCapacity && !_acknowledgedCapacity) {
      setState(() => _err =
          'Bifează confirmarea că accepți depășirea capacității.');
      return;
    }
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
      await repo.create(
        isAdmin: true,
        childId: _child!.id,
        programId: widget.program.id,
        enrolledFrom: _enrolledFrom,
        customMonthlyFee: _parseNum(_feeCtrl.text),
        attendanceDays: _followsAllDays ? null : _pickedDays,
        expectedArrivalTime:
            _arrival == null ? null : _fmtTod(_arrival!),
        enrolledBy: adminId,
      );
      ref.invalidate(afterschoolActiveEnrollmentsForProgramProvider(
          widget.program.id));
      ref.invalidate(afterschoolActiveEnrollmentCountProvider(
          widget.program.id));
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${_child!.fullName} înscris în program.')),
      );
    } catch (e) {
      setState(() {
        _saving = false;
        _err = _prettyError(e.toString());
      });
    }
  }
}

class _ArrivalPicker extends StatelessWidget {
  const _ArrivalPicker({required this.value, required this.onChanged});
  final TimeOfDay? value;
  final ValueChanged<TimeOfDay?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(children: [
      Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final picked = await showTimePicker(
                context: context,
                initialTime: value ?? const TimeOfDay(hour: 14, minute: 0));
            if (picked != null) onChanged(picked);
          },
          child: InputDecorator(
            decoration: buildChildFormInputDeco(theme).copyWith(
                hintText: 'Alege ora (opțional)'),
            child: Row(children: [
              Icon(Icons.access_time,
                  size: 16, color: theme.colorScheme.outline),
              const SizedBox(width: 8),
              Text(value == null ? 'Fără oră' : _fmtTod(value!)),
            ]),
          ),
        ),
      ),
      if (value != null)
        IconButton(
          icon: const Icon(Icons.clear, size: 18),
          tooltip: 'Șterge ora',
          onPressed: () => onChanged(null),
        ),
    ]);
  }
}

String _fmtTod(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

double? _parseNum(String? v) {
  if (v == null) return null;
  final t = v.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

String _fmtFee(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(2);
}

String _prettyError(String raw) {
  if (raw.contains('attendance_days_not_subset_of_program_days')) {
    return 'Zilele selectate nu se încadrează în zilele programului.';
  }
  if (raw.contains('uq_afs_enr_active')) {
    return 'Copilul este deja înscris activ în acest program.';
  }
  if (raw.contains('insufficient_privileges')) {
    return 'Doar administratorii pot înscrie copii.';
  }
  return raw;
}
