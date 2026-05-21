import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../dashboard/providers/dashboard_providers.dart';
import '../providers/enrollment_providers.dart';
import '../providers/workshops_providers.dart';
import 'workshop_basic_info_section.dart';
import 'workshop_form_actions.dart';
import 'workshop_schedule_section.dart';
import 'workshop_trainer_section.dart';
import 'workshop_type_section.dart';

String _generateUuid() {
  final rng = Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class WorkshopFormPage extends ConsumerStatefulWidget {
  const WorkshopFormPage({super.key, this.workshopId});
  final String? workshopId;

  @override
  ConsumerState<WorkshopFormPage> createState() => _WorkshopFormPageState();
}

class _WorkshopFormPageState extends ConsumerState<WorkshopFormPage> {
  bool get _isEditing => widget.workshopId != null;

  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String? _workshopType;
  String? _dayOfWeek;
  String? _trainerId;

  DateTime? _workshopDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  bool _isRecurring = false;
  bool _isActive = true;
  bool _populated = false;
  bool _populateScheduled = false;
  bool _saving = false;
  // Canonical FK to workshop_series.id. The repository mirrors this into
  // both `series_id` and `recurring_series_id` columns on save so the
  // legacy column stays in sync until it is dropped.
  String? _seriesId;
  RecurringScope _applyScope = RecurringScope.thisOnly;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _populate() {
    if (_populated || _populateScheduled || !_isEditing) return;
    final ws = ref.read(workshopByIdProvider(widget.workshopId!)).valueOrNull;
    if (ws == null) return;
    _populateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _populated) return;
      setState(() {
        _populated = true;
        _titleCtrl.text = ws.title;
        _notesCtrl.text = ws.notes ?? '';
        _workshopType = normalizeWorkshopType(ws.workshopType);
        _dayOfWeek = normalizeDayOfWeek(ws.dayOfWeek);
        _trainerId = ws.trainerId;
        _workshopDate = ws.workshopDate;
        _isRecurring = ws.isRecurring ?? false;
        _isActive = ws.isActive ?? true;
        _seriesId = ws.seriesId;
        _startTime = _parseTime(ws.startTime);
        _endTime = _parseTime(ws.endTime);
      });
    });
  }

  TimeOfDay? _parseTime(String? hhmm) {
    if (hhmm == null || hhmm.isEmpty) return null;
    final parts = hhmm.split(':');
    if (parts.length < 2) return null;
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 0,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _workshopDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _workshopDate = picked);
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) setState(() => _startTime = picked);
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked != null) setState(() => _endTime = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_workshopDate == null) {
      _showError('Selectează data atelierului.');
      return;
    }
    if (_startTime == null) {
      _showError('Selectează ora de start.');
      return;
    }
    if (_endTime == null) {
      _showError('Selectează ora de final.');
      return;
    }
    if (_trainerId == null) {
      _showError('Selectează un trainer.');
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(workshopsRepositoryProvider);

      // Ensure a recurring workshop ALWAYS has a series id, including when an
      // existing non-recurring workshop is being flipped to recurring (the
      // form was previously only generating an id on initial create).
      // Without this, the saved row has is_recurring=true but series_id=null,
      // which later breaks workshop_enrollments.
      final needsNewSeriesId =
          _isRecurring && (_seriesId == null || _seriesId!.isEmpty);
      if (needsNewSeriesId) {
        _seriesId = _generateUuid();
      }

      final payload = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'workshop_type': _workshopType,
        'day_of_week': _dayOfWeek,
        'workshop_date': _workshopDate!.toIso8601String().split('T').first,
        'start_time': _formatTod(_startTime!),
        'end_time': _formatTod(_endTime!),
        'trainer_id': _trainerId,
        'notes': _notesCtrl.text.trim().isEmpty
            ? null
            : _notesCtrl.text.trim(),
        'is_recurring': _isRecurring,
        'is_active': _isActive,
        // Canonical column; WorkshopsRepository mirrors this into the
        // legacy `recurring_series_id` column on save.
        if (_isRecurring && needsNewSeriesId)
          'series_id': _seriesId,
      };

      if (_isEditing) {
        final applyToSeries =
            _seriesId != null && _applyScope == RecurringScope.series;
        if (applyToSeries) {
          final seriesPayload = Map<String, dynamic>.from(payload)
            ..remove('workshop_date');
          await repo.updateSeries(
            seriesId: _seriesId!,
            fromDate: _workshopDate!,
            data: seriesPayload,
          );
        } else {
          await repo.update(widget.workshopId!, payload);
        }
      } else {
        await repo.create(payload);
      }

      ref.invalidate(allScheduledWorkshopsProvider);
      ref.invalidate(todayWorkshopsProvider);
      ref.invalidate(workshopsListProvider);
      ref.invalidate(activeWorkshopSeriesProvider);
      ref.invalidate(dashboardStatsProvider);
      if (_isEditing) {
        ref.invalidate(workshopByIdProvider(widget.workshopId!));
        ref.invalidate(workshopDetailsProvider(widget.workshopId!));
        if (_seriesId != null) {
          ref.invalidate(workshopSeriesByIdProvider(_seriesId!));
        }
      }
      if (kDebugMode) debugPrint('[Workshop] providers invalidated after save');

      if (mounted) {
        if (_isEditing) {
          context.go('/workshops/${widget.workshopId}');
        } else {
          context.canPop() ? context.pop() : context.go('/dashboard');
        }
      }
    } catch (e) {
      if (mounted) _showError('Eroare la salvare: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatTod(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isEditing) {
      ref.watch(workshopByIdProvider(widget.workshopId!));
      _populate();
    }

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
        title: Text(_isEditing ? 'Editare atelier' : 'Atelier nou'),
      ),
      body: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 720;
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 40 : 20,
                vertical: 24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      WorkshopBasicInfoSection(
                        titleCtrl: _titleCtrl,
                        notesCtrl: _notesCtrl,
                      ),
                      const SizedBox(height: 16),
                      WorkshopTypeSection(
                        workshopType: _workshopType,
                        dayOfWeek: _dayOfWeek,
                        onTypeChanged: (v) =>
                            setState(() => _workshopType = v),
                        onDayChanged: (v) =>
                            setState(() => _dayOfWeek = v),
                        isWide: isWide,
                      ),
                      const SizedBox(height: 16),
                      WorkshopScheduleSection(
                        workshopDate: _workshopDate,
                        startTime: _startTime,
                        endTime: _endTime,
                        onPickDate: _pickDate,
                        onPickStart: _pickStartTime,
                        onPickEnd: _pickEndTime,
                        isWide: isWide,
                      ),
                      const SizedBox(height: 16),
                      WorkshopTrainerSection(
                        trainerId: _trainerId,
                        onTrainerChanged: (v) =>
                            setState(() => _trainerId = v),
                        onTrainerReset: (v) =>
                            setState(() => _trainerId = v),
                      ),
                      const SizedBox(height: 20),
                      WorkshopFormActions(
                        isActive: _isActive,
                        isRecurring: _isRecurring,
                        onActiveChanged: (v) =>
                            setState(() => _isActive = v),
                        onRecurringChanged: (v) =>
                            setState(() => _isRecurring = v),
                        isEditing: _isEditing,
                        hasRecurringSeries: _seriesId != null,
                        applyScope: _applyScope,
                        onScopeChanged: (v) =>
                            setState(() => _applyScope = v),
                        saving: _saving,
                        onSave: _saving ? null : _save,
                        saveLabel: _isEditing
                            ? 'Salvează modificările'
                            : 'Creează atelierul',
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
