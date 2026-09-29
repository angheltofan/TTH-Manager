import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../auth/providers/auth_providers.dart';
import '../../children/providers/children_providers.dart';
import '../../children/presentation/widgets/child_form_helpers.dart';
import '../domain/afterschool_program.dart';
import '../providers/afterschool_providers.dart';
import 'widgets/program_days_change_dialog.dart';
import 'widgets/weekday_multi_selector.dart';

/// Create / edit an Afterschool program. Full-screen route, matching
/// the workshop/child form convention. Admin-only — the page shows an
/// access-denied view to trainers and parents.
///
/// EDIT MODE + narrowing of `days_of_week`:
///   before firing `updateProgramAtomic`, the page loads active
///   enrollments, computes intersection preview per enrollment, and
///   opens [showProgramDaysChangeDialog]. Save proceeds only when the
///   admin confirms AND there are no blockers.
class AfterschoolProgramFormPage extends ConsumerStatefulWidget {
  const AfterschoolProgramFormPage({super.key, this.programId});
  final String? programId;

  @override
  ConsumerState<AfterschoolProgramFormPage> createState() =>
      _AfterschoolProgramFormPageState();
}

class _AfterschoolProgramFormPageState
    extends ConsumerState<AfterschoolProgramFormPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _feeCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController(text: 'RON');
  final _capacityCtrl = TextEditingController();

  Set<int> _daysOfWeek = {1, 2, 3, 4, 5};
  TimeOfDay _startTime = const TimeOfDay(hour: 13, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  DateTime _activeFrom = _today();
  DateTime? _activeTo;

  bool _saving = false;
  String? _saveError;
  bool _seeded = false;

  bool get _isEditing => widget.programId != null;

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _feeCtrl.dispose();
    _currencyCtrl.dispose();
    _capacityCtrl.dispose();
    super.dispose();
  }

  void _seedFrom(AfterschoolProgram p) {
    if (_seeded) return;
    _seeded = true;
    _nameCtrl.text = p.name;
    _descCtrl.text = p.description ?? '';
    _feeCtrl.text = _fmtMoney(p.monthlyFee);
    _currencyCtrl.text = p.currency;
    _capacityCtrl.text = p.maxCapacity?.toString() ?? '';
    _daysOfWeek = {...p.daysOfWeek};
    _startTime = _parseTod(p.startTime);
    _endTime = _parseTod(p.endTime);
    _activeFrom = p.activeFrom;
    _activeTo = p.activeTo;
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final isAdmin = profile?.isAdmin ?? false;
    if (!isAdmin) return const _AccessDenied();

    if (_isEditing) {
      final async =
          ref.watch(afterschoolProgramByIdProvider(widget.programId!));
      return async.when(
        loading: () =>
            const Scaffold(body: SizedBox.expand(child: AppLoading())),
        error: (e, _) => Scaffold(
          appBar: AppBar(),
          body: Padding(
              padding: const EdgeInsets.all(24),
              child: AppError(message: e.toString())),
        ),
        data: (program) {
          if (program == null) {
            return Scaffold(
              appBar: AppBar(),
              body: const Padding(
                padding: EdgeInsets.all(24),
                child: AppError(message: 'Program inexistent.'),
              ),
            );
          }
          _seedFrom(program);
          return _buildForm(context, existing: program);
        },
      );
    }
    return _buildForm(context, existing: null);
  }

  Widget _buildForm(BuildContext context,
      {required AfterschoolProgram? existing}) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(_isEditing ? 'Editare program' : 'Program nou'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/afterschool/programs'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ChildSectionCard(
                      icon: Icons.info_outline,
                      title: 'Detalii program',
                      child: _basicSection(theme),
                    ),
                    const SizedBox(height: 16),
                    ChildSectionCard(
                      icon: Icons.event_repeat,
                      title: 'Program săptămânal',
                      subtitle:
                          'Zilele în care programul funcționează și intervalul orar.',
                      child: _scheduleSection(theme),
                    ),
                    const SizedBox(height: 16),
                    ChildSectionCard(
                      icon: Icons.payments_outlined,
                      title: 'Tarif și capacitate',
                      child: _feeSection(theme),
                    ),
                    const SizedBox(height: 16),
                    ChildSectionCard(
                      icon: Icons.date_range,
                      title: 'Perioada activă',
                      subtitle:
                          '"Până la" e opțional. Dacă lipsește, programul rămâne activ până la arhivare.',
                      child: _periodSection(theme),
                    ),
                    const SizedBox(height: 20),
                    ChildFormSaveRow(
                      saving: _saving,
                      isEditing: _isEditing,
                      onSave: () => _onSave(existing),
                      saveError: _saveError,
                      createLabel: 'Creează program',
                      cancelFallbackRoute: '/afterschool/programs',
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Sections ────────────────────────────────────────────────────────

  Widget _basicSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChildFormField(
          label: 'Denumire',
          required: true,
          child: TextFormField(
            controller: _nameCtrl,
            decoration: buildChildFormInputDeco(theme).copyWith(
                hintText: 'ex: Afterschool de Robotică'),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Denumirea este obligatorie'
                : null,
          ),
        ),
        const SizedBox(height: 14),
        ChildFormField(
          label: 'Descriere (opțional)',
          child: TextFormField(
            controller: _descCtrl,
            maxLines: 3,
            decoration: buildChildFormInputDeco(theme).copyWith(
                hintText: 'Detalii vizibile administratorilor.'),
          ),
        ),
      ],
    );
  }

  Widget _scheduleSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChildFormField(
          label: 'Zile program',
          required: true,
          child: WeekdayMultiSelector(
            selected: _daysOfWeek,
            onChanged: (next) => setState(() => _daysOfWeek = next),
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (ctx, c) {
          final wide = c.maxWidth >= 480;
          final start = _TimePickField(
            label: 'Începe la',
            value: _startTime,
            onChanged: (t) => setState(() => _startTime = t),
          );
          final end = _TimePickField(
            label: 'Se termină la',
            value: _endTime,
            onChanged: (t) => setState(() => _endTime = t),
          );
          if (wide) {
            return Row(
              children: [
                Expanded(child: start),
                const SizedBox(width: 12),
                Expanded(child: end),
              ],
            );
          }
          return Column(children: [
            start,
            const SizedBox(height: 12),
            end,
          ]);
        }),
      ],
    );
  }

  Widget _feeSection(ThemeData theme) {
    return LayoutBuilder(builder: (ctx, c) {
      final wide = c.maxWidth >= 480;
      final fee = ChildFormField(
        label: 'Tarif lunar',
        required: true,
        child: TextFormField(
          controller: _feeCtrl,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          decoration: buildChildFormInputDeco(theme)
              .copyWith(hintText: 'ex: 1300'),
          validator: (v) {
            final n = _parseNum(v);
            if (n == null || n <= 0) {
              return 'Tarif invalid';
            }
            return null;
          },
        ),
      );
      final currency = ChildFormField(
        label: 'Monedă',
        required: true,
        child: TextFormField(
          controller: _currencyCtrl,
          decoration: buildChildFormInputDeco(theme),
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Monedă obligatorie'
              : null,
        ),
      );
      final cap = ChildFormField(
        label: 'Capacitate maximă (opțional)',
        child: TextFormField(
          controller: _capacityCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: buildChildFormInputDeco(theme)
              .copyWith(hintText: 'ex: 10'),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return null;
            final n = int.tryParse(v.trim());
            if (n == null || n <= 0) return 'Numărul trebuie să fie > 0';
            return null;
          },
        ),
      );
      if (wide) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: fee),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: currency),
            const SizedBox(width: 12),
            Expanded(flex: 3, child: cap),
          ],
        );
      }
      return Column(children: [
        fee,
        const SizedBox(height: 12),
        currency,
        const SizedBox(height: 12),
        cap,
      ]);
    });
  }

  Widget _periodSection(ThemeData theme) {
    return LayoutBuilder(builder: (ctx, c) {
      final wide = c.maxWidth >= 480;
      final from = _DatePickField(
        label: 'De la',
        value: _activeFrom,
        onChanged: (d) {
          if (d != null) setState(() => _activeFrom = d);
        },
      );
      final to = _DatePickField(
        label: 'Până la (opțional)',
        value: _activeTo,
        onChanged: (d) => setState(() => _activeTo = d),
        allowClear: true,
      );
      if (wide) {
        return Row(
          children: [
            Expanded(child: from),
            const SizedBox(width: 12),
            Expanded(child: to),
          ],
        );
      }
      return Column(children: [
        from,
        const SizedBox(height: 12),
        to,
      ]);
    });
  }

  // ── Save flow ──────────────────────────────────────────────────────

  Future<void> _onSave(AfterschoolProgram? existing) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_daysOfWeek.isEmpty) {
      setState(() => _saveError = 'Selectează cel puțin o zi.');
      return;
    }
    if (_timeLE(_endTime, _startTime)) {
      setState(() =>
          _saveError = 'Ora de sfârșit trebuie să fie după ora de început.');
      return;
    }
    if (_activeTo != null && _activeTo!.isBefore(_activeFrom)) {
      setState(() =>
          _saveError = '"Până la" trebuie să fie ≥ "de la".');
      return;
    }

    final profile = ref.read(currentProfileProvider).valueOrNull;
    final adminId = profile?.id;
    if (adminId == null) return;

    final fee = _parseNum(_feeCtrl.text) ?? 0;
    final capacity = _capacityCtrl.text.trim().isEmpty
        ? null
        : int.parse(_capacityCtrl.text.trim());
    final startStr = _fmtTod(_startTime);
    final endStr = _fmtTod(_endTime);

    // Narrowing check + preview dialog: EDIT mode only, and only when
    // the new days_of_week is not a superset of the current days.
    if (existing != null &&
        !_isSameSet(_daysOfWeek, existing.daysOfWeek) &&
        !_daysOfWeek.containsAll(existing.daysOfWeek)) {
      final enrollments = await ref.read(
        afterschoolActiveEnrollmentsForProgramProvider(existing.id).future,
      );
      final impact = computeProgramDaysChangeImpact(
        activeEnrollments: enrollments,
        newProgramDays: _daysOfWeek,
      );
      if (impact.anyChanges) {
        if (!mounted) return;
        final childNames = await _loadChildNamesFor(enrollments);
        if (!mounted) return;
        final ok = await showProgramDaysChangeDialog(
          context: context,
          childNamesById: childNames,
          impact: impact,
        );
        if (ok != true) return;
      }
    }

    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      final repo = ref.read(afterschoolProgramsRepositoryProvider);
      if (existing == null) {
        await repo.create(
          isAdmin: true,
          name: _nameCtrl.text,
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          daysOfWeek: _daysOfWeek,
          startTime: startStr,
          endTime: endStr,
          monthlyFee: fee,
          currency: _currencyCtrl.text.trim(),
          maxCapacity: capacity,
          activeFrom: _activeFrom,
          activeTo: _activeTo,
        );
      } else {
        await repo.updateProgramAtomic(
          isAdmin: true,
          id: existing.id,
          name: _nameCtrl.text,
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          daysOfWeek: _daysOfWeek,
          startTime: startStr,
          endTime: endStr,
          monthlyFee: fee,
          currency: _currencyCtrl.text.trim(),
          maxCapacity: capacity,
          activeFrom: _activeFrom,
          activeTo: _activeTo,
        );
      }

      _invalidateAll(existingId: existing?.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(existing == null
              ? 'Program creat'
              : 'Program actualizat')));
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(existing == null
            ? '/afterschool/programs'
            : '/afterschool/programs/${existing.id}');
      }
    } catch (e) {
      final raw = e.toString();
      setState(() {
        _saveError = _prettyError(raw);
        _saving = false;
      });
    }
  }

  void _invalidateAll({String? existingId}) {
    ref.invalidate(afterschoolProgramsProvider);
    ref.invalidate(afterschoolAllProgramsProvider);
    if (existingId != null) {
      ref.invalidate(afterschoolProgramByIdProvider(existingId));
      ref.invalidate(
          afterschoolActiveEnrollmentsForProgramProvider(existingId));
      ref.invalidate(
          afterschoolActiveEnrollmentCountProvider(existingId));
    }
  }

  Future<Map<String, String>> _loadChildNamesFor(
      List<dynamic> enrollments) async {
    final allChildren = await ref.read(allChildrenProvider.future);
    final byId = <String, String>{
      for (final c in allChildren) c.id: c.fullName,
    };
    return byId;
  }
}

// ── Helpers ──────────────────────────────────────────────────────────

class _TimePickField extends StatelessWidget {
  const _TimePickField({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final TimeOfDay value;
  final ValueChanged<TimeOfDay> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ChildFormField(
      label: label,
      required: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final picked =
              await showTimePicker(context: context, initialTime: value);
          if (picked != null) onChanged(picked);
        },
        child: InputDecorator(
          decoration: buildChildFormInputDeco(theme),
          child: Row(children: [
            Icon(Icons.access_time,
                size: 18, color: theme.colorScheme.outline),
            const SizedBox(width: 8),
            Text(_fmtTod(value)),
          ]),
        ),
      ),
    );
  }
}

class _DatePickField extends StatelessWidget {
  const _DatePickField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.allowClear = false,
  });
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool allowClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = value == null
        ? 'Fără dată'
        : '${value!.day.toString().padLeft(2, '0')}.'
            '${value!.month.toString().padLeft(2, '0')}.${value!.year}';
    return ChildFormField(
      label: label,
      required: !allowClear,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            firstDate: DateTime(2020, 1, 1),
            lastDate: DateTime(2100, 12, 31),
            initialDate: value ?? DateTime.now(),
          );
          if (picked != null) {
            onChanged(DateTime(picked.year, picked.month, picked.day));
          }
        },
        child: InputDecorator(
          decoration: buildChildFormInputDeco(theme),
          child: Row(children: [
            Icon(Icons.calendar_today,
                size: 16, color: theme.colorScheme.outline),
            const SizedBox(width: 8),
            Expanded(child: Text(display)),
            if (allowClear && value != null)
              IconButton(
                icon: const Icon(Icons.clear, size: 16),
                onPressed: () => onChanged(null),
                tooltip: 'Șterge data',
              ),
          ]),
        ),
      ),
    );
  }
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/afterschool/programs'),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline_rounded,
                size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text('Acces interzis',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Doar administratorii pot gestiona programele Afterschool.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      ),
    );
  }
}

// ── Utilities (kept local; no shared money/time helper in the app) ───

String _fmtTod(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

TimeOfDay _parseTod(String hhmmss) {
  final parts = hhmmss.split(':');
  return TimeOfDay(
    hour: int.tryParse(parts[0]) ?? 0,
    minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
  );
}

bool _timeLE(TimeOfDay a, TimeOfDay b) {
  final am = a.hour * 60 + a.minute;
  final bm = b.hour * 60 + b.minute;
  return am <= bm;
}

double? _parseNum(String? v) {
  if (v == null) return null;
  final t = v.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

String _fmtMoney(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(2);
}

bool _isSameSet(Set<int> a, Set<int> b) =>
    a.length == b.length && a.containsAll(b);

String _prettyError(String raw) {
  if (raw.contains('enrollment_would_have_no_days')) {
    return 'Un copil ar rămâne fără nicio zi de participare. '
        'Refresh apoi actualizează programul individual afectat.';
  }
  if (raw.contains('insufficient_privileges')) {
    return 'Doar administratorii pot salva un program Afterschool.';
  }
  if (raw.contains('invalid_arguments')) {
    return raw.split('invalid_arguments:').last.trim();
  }
  return raw;
}
