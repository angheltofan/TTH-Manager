import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../domain/parent_link.dart';
import '../../providers/parent_links_providers.dart';

/// Two-mode dialog used by the admin "Adaugă părinte" action on the
/// Child Details page:
///
///   • Tab A — link an existing `profiles` row with `role='parent'`
///             (fully functional via PostgREST + RLS).
///   • Tab B — invite/create a new parent (P5 Edge Function scaffold;
///             the form is built but submit surfaces an explanatory
///             snackbar and does NOT touch the database).
class AddParentDialog extends ConsumerStatefulWidget {
  const AddParentDialog({super.key, required this.childId});

  final String childId;

  @override
  ConsumerState<AddParentDialog> createState() => _AddParentDialogState();
}

class _AddParentDialogState extends ConsumerState<AddParentDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: Column(
          children: [
            // -- Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Text(
                    'Adaugă părinte',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // -- Tabs
            TabBar(
              controller: _tabs,
              labelColor: AppColors.purple,
              indicatorColor: AppColors.purple,
              tabs: const [
                Tab(text: 'Asociază existent'),
                Tab(text: 'Creează nou'),
              ],
            ),
            // -- Body
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _LinkExistingTab(childId: widget.childId),
                  _CreateNewTab(childId: widget.childId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab A: link an existing parent ─────────────────────────────────────────

class _LinkExistingTab extends ConsumerStatefulWidget {
  const _LinkExistingTab({required this.childId});

  final String childId;

  @override
  ConsumerState<_LinkExistingTab> createState() => _LinkExistingTabState();
}

class _LinkExistingTabState extends ConsumerState<_LinkExistingTab> {
  String _search = '';
  ParentProfile? _selected;
  final _relCtrl = TextEditingController();
  bool _isPrimary = false;
  bool _saving = false;
  bool _loading = false;
  List<ParentProfile> _results = const [];

  @override
  void initState() {
    super.initState();
    _runSearch('');
  }

  @override
  void dispose() {
    _relCtrl.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String q) async {
    setState(() {
      _loading = true;
      _search = q;
    });
    final isAdmin =
        ref.read(currentProfileProvider).valueOrNull?.isAdmin ?? false;
    try {
      final results = await ref
          .read(parentLinksRepositoryProvider)
          .searchExistingParents(q, isAdmin: isAdmin);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_selected == null) return;
    setState(() => _saving = true);
    final isAdmin =
        ref.read(currentProfileProvider).valueOrNull?.isAdmin ?? false;
    try {
      await ref.read(parentLinksRepositoryProvider).linkExistingParent(
            isAdmin: isAdmin,
            childId: widget.childId,
            parentId: _selected!.id,
            relationship:
                _relCtrl.text.trim().isEmpty ? null : _relCtrl.text.trim(),
            isPrimary: _isPrimary,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage(e))),
      );
      setState(() => _saving = false);
    }
  }

  static String _errorMessage(Object e) {
    final s = e.toString();
    if (s.contains('42501') || s.contains('403') || s.contains('permission')) {
      return 'Permisiune insuficientă.';
    }
    return 'Eroare: $e';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Caută părinte (nume)…',
              prefixIcon: const Icon(Icons.search, size: 18),
              isDense: true,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: _runSearch,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: _loading
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _results.isEmpty
                    ? Center(
                        child: Text(
                          _search.isEmpty
                              ? 'Niciun părinte existent.'
                              : 'Niciun rezultat pentru "$_search".',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.outline),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final p = _results[i];
                          final selected = _selected?.id == p.id;
                          return ListTile(
                            dense: true,
                            selected: selected,
                            selectedTileColor:
                                AppColors.purple.withValues(alpha: 0.08),
                            title: Text(
                              p.fullName.isEmpty
                                  ? '(fără nume)'
                                  : p.fullName,
                            ),
                            trailing: selected
                                ? const Icon(Icons.check_circle,
                                    color: AppColors.purple, size: 20)
                                : null,
                            onTap: () => setState(() => _selected = p),
                          );
                        },
                      ),
          ),
          const Divider(height: 24),
          TextField(
            controller: _relCtrl,
            decoration: InputDecoration(
              labelText: 'Relația (opțional)',
              hintText: 'mamă, tată, tutore, altul',
              isDense: true,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Checkbox(
                value: _isPrimary,
                onChanged: (v) => setState(() => _isPrimary = v ?? false),
                activeColor: AppColors.purple,
              ),
              const Text('Contact principal'),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Anulează'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed:
                    _saving || _selected == null ? null : _save,
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.purple),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Asociază'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Tab B: scaffold for the P5 invite flow ──────────────────────────────────

class _CreateNewTab extends ConsumerStatefulWidget {
  const _CreateNewTab({required this.childId});

  final String childId;

  @override
  ConsumerState<_CreateNewTab> createState() => _CreateNewTabState();
}

class _CreateNewTabState extends ConsumerState<_CreateNewTab> {
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _relCtrl = TextEditingController();
  bool _isPrimary = false;
  bool _busy = false;

  @override
  void dispose() {
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _emailCtrl.dispose();
    _relCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final firstName = _firstCtrl.text.trim();
    final lastName = _lastCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final relationship =
        _relCtrl.text.trim().isEmpty ? null : _relCtrl.text.trim();

    final validationError = _validate(
      firstName: firstName,
      lastName: lastName,
      email: email,
    );
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError)),
      );
      return;
    }

    setState(() => _busy = true);
    final isAdmin =
        ref.read(currentProfileProvider).valueOrNull?.isAdmin ?? false;
    try {
      final result =
          await ref.read(parentLinksRepositoryProvider).prepareCreateParent(
                isAdmin: isAdmin,
                childId: widget.childId,
                firstName: firstName,
                lastName: lastName,
                email: email,
                relationship: relationship,
                isPrimary: _isPrimary,
              );
      if (!mounted) return;
      final message = result.inviteSent
          ? 'Emailul pentru setarea parolei a fost trimis.'
          : 'Cont existent asociat.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      Navigator.pop(context, true);
    } on ParentInviteException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_humanizeError(e))),
      );
      setState(() => _busy = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Eroare neașteptată: $e')),
      );
      setState(() => _busy = false);
    }
  }

  static String? _validate({
    required String firstName,
    required String lastName,
    required String email,
  }) {
    if (firstName.isEmpty) return 'Prenumele este obligatoriu.';
    if (lastName.isEmpty) return 'Numele este obligatoriu.';
    final emailOk =
        RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
    if (!emailOk) return 'Adresa de email este invalidă.';
    return null;
  }

  static String _humanizeError(ParentInviteException e) {
    switch (e.status) {
      case 400:
        return 'Date invalide: ${e.message}';
      case 401:
        return 'Sesiune expirată. Reautentificați-vă.';
      case 403:
        return 'Permisiune insuficientă.';
      case 409:
        // Server provides a user-facing Romanian message (single-role
        // guard); pass through verbatim.
        return e.message;
      case 429:
        // Server provides a user-facing Romanian message (email
        // rate-limit); pass through verbatim.
        return e.message;
      case 502:
        return 'Trimiterea invitației a eșuat. Verificați adresa de email.';
      default:
        return 'Eroare la crearea părintelui (${e.status}).';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    size: 18, color: theme.colorScheme.outline),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Crearea părinților noi necesită Edge Function (P5). '
                    'Formularul este disponibil; activarea trimite invitația.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _field('Prenume', _firstCtrl),
          const SizedBox(height: 10),
          _field('Nume', _lastCtrl),
          const SizedBox(height: 10),
          _field('Email', _emailCtrl, keyboard: TextInputType.emailAddress),
          const SizedBox(height: 10),
          _field('Relația', _relCtrl, hint: 'mamă, tată, tutore, altul'),
          const SizedBox(height: 10),
          Row(
            children: [
              Checkbox(
                value: _isPrimary,
                onChanged: (v) => setState(() => _isPrimary = v ?? false),
                activeColor: AppColors.purple,
              ),
              const Text('Contact principal'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                child: const Text('Anulează'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.purple),
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Invită părinte'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController c,
      {TextInputType? keyboard, String? hint}) {
    return TextField(
      controller: c,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
