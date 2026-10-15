import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_client_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/visitor_candidate.dart';
import '../../providers/workshops_providers.dart';

/// Dialog for "+ Adaugă participant din altă grupă".
///
/// Lists children with an active enrollment on another workshop_series
/// sharing the same workshop_type, excluding those already present on
/// this physical session. Multi-enrollment candidates force an explicit
/// enrollment choice before confirming.
///
/// Confirming inserts a pending attendance row (status NULL) with
/// `credited_series_id` set to the chosen enrollment; it does NOT
/// consume a billing credit until the trainer marks the child present
/// via the standard attendance control.
class AddVisitorDialog extends ConsumerStatefulWidget {
  const AddVisitorDialog({
    super.key,
    required this.seriesId,
    required this.scheduledWorkshopId,
  });

  final String seriesId;
  final String scheduledWorkshopId;

  @override
  ConsumerState<AddVisitorDialog> createState() => _AddVisitorDialogState();
}

class _AddVisitorDialogState extends ConsumerState<AddVisitorDialog> {
  String _query = '';
  String? _selectedChildId;
  String? _selectedEnrollmentSeriesId;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final key = VisitorCandidatesKey(
      seriesId: widget.seriesId,
      scheduledWorkshopId: widget.scheduledWorkshopId,
    );
    final candidatesAsync = ref.watch(visitorCandidatesProvider(key));
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Adaugă participant din altă grupă'),
      content: SizedBox(
        width: 400,
        child: candidatesAsync.when(
          loading: () => const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => _ErrorRow(message: '$e'),
          data: (candidates) {
            final filtered = _filter(candidates, _query);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Caută copil…',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 10),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Niciun copil eligibil din alt grup al aceluiași workshop.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final c = filtered[i];
                        return _CandidateTile(
                          candidate: c,
                          selectedChildId: _selectedChildId,
                          selectedEnrollmentSeriesId: _selectedEnrollmentSeriesId,
                          onPick: (childId, seriesId) {
                            setState(() {
                              _selectedChildId = childId;
                              _selectedEnrollmentSeriesId = seriesId;
                            });
                          },
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Anulează'),
        ),
        FilledButton(
          onPressed: _canConfirm() ? _confirm : null,
          style: FilledButton.styleFrom(backgroundColor: AppColors.purple),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Adaugă'),
        ),
      ],
    );
  }

  bool _canConfirm() {
    return !_saving &&
        _selectedChildId != null &&
        _selectedEnrollmentSeriesId != null;
  }

  List<VisitorCandidate> _filter(List<VisitorCandidate> xs, String q) {
    if (q.trim().isEmpty) return xs;
    final needle = q.toLowerCase();
    return xs.where((c) => c.fullName.toLowerCase().contains(needle)).toList();
  }

  Future<void> _confirm() async {
    if (!_canConfirm()) return;
    setState(() => _saving = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw StateError('No authenticated session');
      await ref.read(workshopsRepositoryProvider).addVisitor(
            isStaff: true,
            scheduledWorkshopId: widget.scheduledWorkshopId,
            childId: _selectedChildId!,
            creditedSeriesId: _selectedEnrollmentSeriesId!,
            markedBy: userId,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nu am putut adăuga participantul: $e')),
      );
      setState(() => _saving = false);
    }
  }
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({
    required this.candidate,
    required this.selectedChildId,
    required this.selectedEnrollmentSeriesId,
    required this.onPick,
  });

  final VisitorCandidate candidate;
  final String? selectedChildId;
  final String? selectedEnrollmentSeriesId;
  final void Function(String childId, String enrollmentSeriesId) onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPicked = selectedChildId == candidate.childId;
    if (candidate.needsEnrollmentChoice) {
      return ExpansionTile(
        key: PageStorageKey(candidate.childId),
        initiallyExpanded: isPicked,
        title: Text(candidate.fullName),
        subtitle: Text(
          'Mai multe înscrieri active — alege grupa',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        children: [
          for (final enr in candidate.enrollments)
            ListTile(
              dense: true,
              leading: Icon(
                selectedChildId == candidate.childId &&
                        selectedEnrollmentSeriesId == enr.seriesId
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 20,
                color: AppColors.purple,
              ),
              title: Text(enr.regularGroupLabel),
              subtitle: Text(
                enr.seriesTitle,
                style: theme.textTheme.bodySmall,
              ),
              onTap: () => onPick(candidate.childId, enr.seriesId),
            ),
        ],
      );
    }
    final single = candidate.enrollments.first;
    final picked = selectedChildId == candidate.childId &&
        selectedEnrollmentSeriesId == single.seriesId;
    return ListTile(
      dense: true,
      leading: Icon(
        picked ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        size: 20,
        color: AppColors.purple,
      ),
      title: Text(candidate.fullName),
      subtitle: Text(single.regularGroupLabel),
      onTap: () => onPick(candidate.childId, single.seriesId),
    );
  }
}

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
