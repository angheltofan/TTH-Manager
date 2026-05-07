import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/children_providers.dart';
import 'widgets/child_form_contact.dart';
import 'widgets/child_form_helpers.dart';
import 'widgets/child_form_other.dart';
import 'widgets/child_form_personal.dart';

class ChildFormPage extends ConsumerStatefulWidget {
  const ChildFormPage({super.key, this.childId});

  final String? childId;

  @override
  ConsumerState<ChildFormPage> createState() => _ChildFormPageState();
}

class _ChildFormPageState extends ConsumerState<ChildFormPage> {
  bool get _isEditing => widget.childId != null;

  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _parentNameCtrl = TextEditingController();
  final _parentPhoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime? _birthDate;
  bool _isActive = true;
  bool _saving = false;
  bool _initialized = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _firstNameCtrl.addListener(_maybeComputeAge);
    _lastNameCtrl.addListener(_maybeComputeAge);
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _ageCtrl.dispose();
    _parentNameCtrl.dispose();
    _parentPhoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _maybeComputeAge() {
    if (_birthDate != null) _computeAge(_birthDate!);
  }

  void _computeAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    _ageCtrl.text = '$age';
  }

  void _populateFromChild() {
    if (!_isEditing || _initialized) return;
    final child =
        ref.read(childDetailProvider(widget.childId!)).valueOrNull;
    if (child == null) return;
    _initialized = true;
    _firstNameCtrl.text = child.firstName;
    _lastNameCtrl.text = child.lastName;
    if (child.birthDate != null) {
      _birthDate = child.birthDate;
      _computeAge(child.birthDate!);
    } else if (child.age != null) {
      _ageCtrl.text = '${child.age}';
    }
    _parentNameCtrl.text = child.parentName ?? '';
    _parentPhoneCtrl.text = child.parentPhone ?? '';
    _notesCtrl.text = child.notes ?? '';
    _isActive = child.isActive ?? true;
  }

  Future<void> _pickDate() async {
    final initial = _birthDate ??
        DateTime.now().subtract(const Duration(days: 365 * 8));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
      _computeAge(picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final data = <String, dynamic>{
      'first_name': _firstNameCtrl.text.trim(),
      'last_name': _lastNameCtrl.text.trim(),
      if (_birthDate != null)
        'birth_date': _birthDate!.toIso8601String().substring(0, 10),
      if (_ageCtrl.text.trim().isNotEmpty)
        'age': int.tryParse(_ageCtrl.text.trim()),
      if (_parentNameCtrl.text.trim().isNotEmpty)
        'parent_name': _parentNameCtrl.text.trim(),
      if (_parentPhoneCtrl.text.trim().isNotEmpty)
        'parent_phone': _parentPhoneCtrl.text.trim(),
      if (_notesCtrl.text.trim().isNotEmpty)
        'notes': _notesCtrl.text.trim(),
      'is_active': _isActive,
    };
    try {
      final repo = ref.read(childrenRepositoryProvider);
      if (_isEditing) {
        await repo.update(widget.childId!, data);
      } else {
        await repo.create(data);
      }
      ref.invalidate(allChildrenProvider);
      if (!mounted) return;
      context.canPop() ? context.pop() : context.go('/children');
    } catch (e) {
      setState(() {
        _saveError = e.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    if (profile != null && !profile.isAdmin) {
      return const ChildFormAccessDenied();
    }
    if (_isEditing) {
      final childAsync = ref.watch(childDetailProvider(widget.childId!));
      if (childAsync.isLoading) return const Scaffold(body: AppLoading());
      if (childAsync.hasError) {
        return Scaffold(
            body: Center(
                child: AppError(message: childAsync.error.toString())));
      }
      _populateFromChild();
    }

    final inputDeco = buildChildFormInputDeco(theme);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/children'),
        ),
        title: Text(_isEditing ? 'Editare copil' : 'Copil nou'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ChildSectionCard(
                    icon: Icons.person_outline,
                    title: 'Date personale',
                    child: ChildFormPersonal(
                      firstNameCtrl: _firstNameCtrl,
                      lastNameCtrl: _lastNameCtrl,
                      ageCtrl: _ageCtrl,
                      birthDate: _birthDate,
                      inputDeco: inputDeco,
                      onPickDate: _pickDate,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ChildSectionCard(
                    icon: Icons.contact_phone_outlined,
                    title: 'Contact',
                    child: ChildFormContact(
                      parentNameCtrl: _parentNameCtrl,
                      parentPhoneCtrl: _parentPhoneCtrl,
                      inputDeco: inputDeco,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ChildSectionCard(
                    icon: Icons.sticky_note_2_outlined,
                    title: 'Alte informații',
                    child: ChildFormOther(
                      notesCtrl: _notesCtrl,
                      isActive: _isActive,
                      onActiveChanged: (v) => setState(() => _isActive = v),
                      inputDeco: inputDeco,
                    ),
                  ),
                  const SizedBox(height: 28),
                  ChildFormSaveRow(
                    saving: _saving,
                    isEditing: _isEditing,
                    onSave: _save,
                    saveError: _saveError,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
