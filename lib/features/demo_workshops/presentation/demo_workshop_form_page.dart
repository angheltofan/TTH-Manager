import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../auth/providers/auth_providers.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../../workshops/domain/workshop_series.dart';
import '../providers/demo_workshops_providers.dart';

// ── DemoWorkshopFormPage ──────────────────────────────────────────────────────

class DemoWorkshopFormPage extends ConsumerStatefulWidget {
  const DemoWorkshopFormPage({super.key});

  @override
  ConsumerState<DemoWorkshopFormPage> createState() =>
      _DemoWorkshopFormPageState();
}

class _DemoWorkshopFormPageState extends ConsumerState<DemoWorkshopFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _parentNameCtrl = TextEditingController();
  final _parentPhoneCtrl = TextEditingController();
  final _parentEmailCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  WorkshopSeries? _selectedSeries;
  DateTime _demoDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 11, minute: 0);
  bool _saving = false;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _parentNameCtrl.dispose();
    _parentPhoneCtrl.dispose();
    _parentEmailCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static TimeOfDay _parseHHMM(String t) {
    final p = t.split(':');
    return TimeOfDay(
      hour: int.tryParse(p[0]) ?? 0,
      minute: int.tryParse(p.length > 1 ? p[1] : '0') ?? 0,
    );
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:00';

  static String _seriesLabel(WorkshopSeries s) {
    final start = formatTimeString(s.startTime);
    final end = s.endTime != null ? formatTimeString(s.endTime!) : '';
    final timeRange = end.isNotEmpty ? '$start–$end' : start;
    final day = s.dayOfWeek ?? '';
    final trainer = s.trainerName ?? '—';
    return '${s.title} • $day $timeRange • $trainer';
  }

  void _onSeriesSelected(WorkshopSeries? series) {
    setState(() {
      _selectedSeries = series;
      if (series != null) {
        _startTime = _parseHHMM(series.startTime);
        if (series.endTime != null) {
          _endTime = _parseHHMM(series.endTime!);
        }
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _demoDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _demoDate = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final initial = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSeries == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selectează un atelier demo.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final userId = ref.read(currentUserProvider)?.id ?? '';
      final series = _selectedSeries!;
      await ref.read(demoWorkshopsRepositoryProvider).create({
        'child_first_name': _firstNameCtrl.text.trim(),
        'child_last_name': _lastNameCtrl.text.trim(),
        'parent_name': _parentNameCtrl.text.trim(),
        'parent_phone': _parentPhoneCtrl.text.trim(),
        if (_parentEmailCtrl.text.trim().isNotEmpty)
          'parent_email': _parentEmailCtrl.text.trim(),
        'workshop_type': series.workshopType ?? '',
        'workshop_title': series.title,
        'demo_date':
            '${_demoDate.year}-'
            '${_demoDate.month.toString().padLeft(2, '0')}-'
            '${_demoDate.day.toString().padLeft(2, '0')}',
        'start_time': _fmtTime(_startTime),
        'end_time': _fmtTime(_endTime),
        'trainer_id': series.trainerId,
        if (_notesCtrl.text.trim().isNotEmpty)
          'notes': _notesCtrl.text.trim(),
        'status': 'scheduled',
        'created_by': userId,
      });
      ref.invalidate(todayDemoWorkshopsProvider);
      ref.invalidate(dashboardStatsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demo programat cu succes.')),
        );
        context.canPop() ? context.pop() : context.go('/dashboard');
      }
    } on PostgrestException catch (e) {
      if (!mounted) return;
      final isPermission =
          e.code == '42501' || (e.message.contains('permission denied'));
      final msg = isPermission
          ? 'Nu ai permisiunea să programezi ateliere demo. '
              'Verifică rolul contului sau politicile RLS.'
          : 'Eroare la salvare. Încearcă din nou.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('A apărut o eroare. Încearcă din nou.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final seriesAsync = ref.watch(activeSeriesForDemoProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/dashboard'),
        ),
        title: const Text('Programează demo'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 48),
          children: [
            // ── Date copil ──────────────────────────────────────────────────
            _SectionTitle('Date copil'),
            const SizedBox(height: 8),
            // Responsive name row: side-by-side ≥ 360 px, stacked below
            LayoutBuilder(builder: (context, box) {
              final wide = box.maxWidth >= 360;
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child: _Field(
                            ctrl: _firstNameCtrl,
                            label: 'Prenume',
                            required: true)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _Field(
                            ctrl: _lastNameCtrl,
                            label: 'Nume',
                            required: true)),
                  ],
                );
              }
              return Column(
                children: [
                  _Field(
                      ctrl: _firstNameCtrl,
                      label: 'Prenume',
                      required: true),
                  const SizedBox(height: 10),
                  _Field(
                      ctrl: _lastNameCtrl, label: 'Nume', required: true),
                ],
              );
            }),
            const SizedBox(height: 16),

            // ── Date părinte ────────────────────────────────────────────────
            _SectionTitle('Date părinte'),
            const SizedBox(height: 8),
            _Field(ctrl: _parentNameCtrl, label: 'Nume părinte'),
            const SizedBox(height: 10),
            _Field(
              ctrl: _parentPhoneCtrl,
              label: 'Telefon',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 10),
            _Field(
              ctrl: _parentEmailCtrl,
              label: 'Email (opțional)',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),

            // ── Atelier demo ────────────────────────────────────────────────
            _SectionTitle('Atelier demo'),
            const SizedBox(height: 8),
            seriesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) =>
                  Text('Eroare la încărcare: $e',
                      style: TextStyle(color: theme.colorScheme.error)),
              data: (seriesList) => DropdownButtonFormField<WorkshopSeries>(
                value: _selectedSeries,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Selectează atelierul *',
                  prefixIcon: Icon(Icons.event_outlined),
                ),
                items: seriesList.map((s) {
                  return DropdownMenuItem<WorkshopSeries>(
                    value: s,
                    child: Text(
                      _seriesLabel(s),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: _onSeriesSelected,
                validator: (_) =>
                    _selectedSeries == null ? 'Selectează un atelier' : null,
              ),
            ),
            if (_selectedSeries != null) ...[
              const SizedBox(height: 10),
              _SeriesInfoChip(series: _selectedSeries!),
            ],
            const SizedBox(height: 16),

            // ── Dată și oră ─────────────────────────────────────────────────
            _SectionTitle('Dată și oră'),
            const SizedBox(height: 8),
            _PickerTile(
              icon: Icons.calendar_today_outlined,
              label: 'Data demo',
              value: formatDate(_demoDate),
              onTap: _pickDate,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _PickerTile(
                    icon: Icons.schedule_outlined,
                    label: 'Ora start',
                    value: _startTime.format(context),
                    onTap: () => _pickTime(true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PickerTile(
                    icon: Icons.schedule_outlined,
                    label: 'Ora final',
                    value: _endTime.format(context),
                    onTap: () => _pickTime(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Observații ──────────────────────────────────────────────────
            _SectionTitle('Observații'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Note (opțional)',
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              minLines: 2,
            ),
            const SizedBox(height: 28),

            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.purple,
                minimumSize: const Size.fromHeight(48),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Salvează demo'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chip that shows which trainer is auto-assigned ────────────────────────────

class _SeriesInfoChip extends StatelessWidget {
  const _SeriesInfoChip({required this.series});
  final WorkshopSeries series;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.purple.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.purple.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.person_pin_outlined,
              size: 16, color: AppColors.purple),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Trainer: ${series.trainerName ?? '—'}  ·  '
              '${series.workshopType ?? ''}',
              style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.purple, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable small widgets ────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppColors.purple,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.ctrl,
    required this.label,
    this.required = false,
    this.keyboardType,
  });
  final TextEditingController ctrl;
  final String label;
  final bool required;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration:
          InputDecoration(labelText: required ? '$label *' : label),
      validator: required
          ? (v) =>
              v == null || v.trim().isEmpty ? 'Câmp obligatoriu' : null
          : null,
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(10),
          color: theme.inputDecorationTheme.fillColor,
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: theme.colorScheme.outline),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline)),
                  Text(value,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 16, color: theme.colorScheme.outline),
          ],
        ),
      ),
    );
  }
}

