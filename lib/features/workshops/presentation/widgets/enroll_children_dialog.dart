import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../providers/enrollment_providers.dart';

/// Dialog for enrolling multiple children in a workshop series.
class EnrollChildrenDialog extends ConsumerStatefulWidget {
  const EnrollChildrenDialog({super.key, required this.seriesId});

  final String seriesId;

  @override
  ConsumerState<EnrollChildrenDialog> createState() =>
      _EnrollChildrenDialogState();
}

class _EnrollChildrenDialogState
    extends ConsumerState<EnrollChildrenDialog> {
  final Set<String> _selected = {};
  String _search = '';
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final availableAsync =
        ref.watch(availableChildrenForSeriesProvider(widget.seriesId));
    final theme = Theme.of(context);

    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Text(
                    'Adaugă copii',
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

            // ── Search ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Caută după nume…',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (v) =>
                    setState(() => _search = v.trim().toLowerCase()),
              ),
            ),

            // ── List ──────────────────────────────────────────────────
            Expanded(
              child: availableAsync.when(
                loading: () => const Center(
                    child:
                        CircularProgressIndicator(strokeWidth: 2)),
                error: (e, _) =>
                    Center(child: Text('Eroare: $e')),
                data: (children) {
                  final filtered = _search.isEmpty
                      ? children
                      : children.where((c) {
                          final name =
                              '${c['first_name']} ${c['last_name']}'
                                  .toLowerCase();
                          return name.contains(_search);
                        }).toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Niciun copil disponibil.'),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final c = filtered[i];
                      final id = c['id'] as String;
                      final name =
                          '${c['first_name']} ${c['last_name']}';
                      return CheckboxListTile(
                        value: _selected.contains(id),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selected.add(id);
                          } else {
                            _selected.remove(id);
                          }
                        }),
                        title: Text(
                          name,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(
                                  fontWeight: FontWeight.w500),
                        ),
                        dense: true,
                        activeColor: AppColors.purple,
                        controlAffinity:
                            ListTileControlAffinity.leading,
                      );
                    },
                  );
                },
              ),
            ),

            // ── Actions ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _saving ? null : () => Navigator.pop(context),
                    child: const Text('Anulează'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed:
                        _saving || _selected.isEmpty ? null : _save,
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.purple),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white),
                          )
                        : Text(
                            'Adaugă${_selected.isEmpty ? '' : ' (${_selected.length})'}'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final isStaff =
          ref.read(currentProfileProvider).valueOrNull?.isStaff ?? false;
      await ref
          .read(enrollmentRepositoryProvider)
          .enrollChildrenInWorkshopSeries(
              widget.seriesId, _selected.toList(),
              isStaff: isStaff);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        final msg = _errorMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg)));
        setState(() => _saving = false);
      }
    }
  }

  static String _errorMessage(Object e) {
    final s = e.toString();
    if (s.contains('42501') || s.contains('403') || s.contains('permission')) {
      return 'Permisiune insuficientă. Contactați administratorul.';
    }
    return 'Eroare: $e';
  }
}
