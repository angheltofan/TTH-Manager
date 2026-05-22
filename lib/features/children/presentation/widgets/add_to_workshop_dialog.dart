import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../workshops/providers/enrollment_providers.dart';

/// Single-select dialog for enrolling a child in a workshop series.
/// Uses [availableWorkshopSeriesForChildProvider] which already excludes
/// series the child is currently enrolled in.
class AddToWorkshopDialog extends ConsumerStatefulWidget {
  const AddToWorkshopDialog({super.key, required this.childId});

  final String childId;

  @override
  ConsumerState<AddToWorkshopDialog> createState() =>
      _AddToWorkshopDialogState();
}

class _AddToWorkshopDialogState
    extends ConsumerState<AddToWorkshopDialog> {
  String? _selectedSeriesId;
  String _search = '';
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final availableAsync =
        ref.watch(availableWorkshopSeriesForChildProvider(widget.childId));
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
            // -- Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Text(
                    'Adaugă atelier',
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

            // -- Search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Caută după titlu, tip, zi…',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (v) =>
                    setState(() => _search = v.trim().toLowerCase()),
              ),
            ),

            // -- List
            Expanded(
              child: availableAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
                error: (e, _) {
                  final msg = _errorMessage(e);
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 32, color: AppColors.error),
                          const SizedBox(height: 10),
                          Text(msg,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: AppColors.error)),
                        ],
                      ),
                    ),
                  );
                },
                data: (available) {
                  final filtered = _search.isEmpty
                      ? available
                      : available.where((s) {
                          final haystack =
                              '${s.title} ${s.workshopType ?? ''} ${s.dayOfWeek ?? ''}'
                                  .toLowerCase();
                          return haystack.contains(_search);
                        }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          available.isEmpty
                              ? 'Copilul este deja înscris în toate atelierele active.'
                              : 'Niciun atelier nu corespunde căutării.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline),
                        ),
                      ),
                    );
                  }

                  return RadioGroup<String>(
                    groupValue: _selectedSeriesId,
                    onChanged: (v) =>
                        setState(() => _selectedSeriesId = v),
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final s = filtered[i];
                        final endLabel = s.endTime != null
                            ? formatTimeString(s.endTime!)
                            : '';
                        final timeLabel =
                            '${formatTimeString(s.startTime)} – $endLabel';
                        final subtitle = [
                          if (s.workshopType != null &&
                              s.workshopType!.isNotEmpty)
                            s.workshopType!,
                          if (s.dayOfWeek != null &&
                              s.dayOfWeek!.isNotEmpty)
                            s.dayOfWeek!,
                          timeLabel,
                        ].join(' · ');

                        return RadioListTile<String>(
                          value: s.id,
                          title: Text(
                            s.title,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          subtitle: subtitle.isNotEmpty
                              ? Text(subtitle,
                                  style: theme.textTheme.bodySmall)
                              : null,
                          dense: true,
                          activeColor: AppColors.purple,
                          controlAffinity:
                              ListTileControlAffinity.leading,
                        );
                      },
                    ),
                  );
                },
              ),
            ),

            // -- Actions
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
                    onPressed: _saving || _selectedSeriesId == null
                        ? null
                        : _save,
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
                        : const Text('Înscrie'),
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
    if (_selectedSeriesId == null) return;
    setState(() => _saving = true);
    try {
      final isStaff =
          ref.read(currentProfileProvider).valueOrNull?.isStaff ?? false;
      await ref
          .read(enrollmentRepositoryProvider)
          .enrollChildInWorkshopSeries(
              widget.childId, _selectedSeriesId!,
              isStaff: isStaff);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_errorMessage(e))));
        setState(() => _saving = false);
      }
    }
  }

  static String _errorMessage(Object e) {
    final s = e.toString();
    if (s.contains('42501') ||
        s.contains('403') ||
        s.contains('permission')) {
      return 'Permisiune insuficientă. Contactați administratorul.';
    }
    return 'Eroare: $e';
  }
}
