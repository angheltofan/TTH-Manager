import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/learning_level.dart';
import '../../providers/child_details_providers.dart';
import '../../providers/children_providers.dart';

/// Compact dialog for the "Parcurs TTH" section — admin + trainer
/// pick a learning level + progress for one child.
///
/// Writes through `ChildrenRepository.setLearningLevel`, which calls
/// the `set_child_learning_level(uuid, text, int)` RPC. The RPC is
/// gated server-side by `is_staff()`; this dialog does not disable
/// the Save button on role, because the RPC refuses parents / anons
/// before any damage can occur. The returned object is a full
/// `Child` row so the caller gets the authoritative level + progress
/// back without another SELECT.
class LevelProgressDialog extends ConsumerStatefulWidget {
  const LevelProgressDialog({
    super.key,
    required this.childId,
    required this.childFullName,
    required this.initialLevel,
    required this.initialProgress,
  });

  final String childId;
  final String childFullName;

  /// Current `children.current_level` — null = not placed yet.
  final String? initialLevel;

  /// Current `children.level_progress` — null = not placed yet.
  final int? initialProgress;

  @override
  ConsumerState<LevelProgressDialog> createState() =>
      _LevelProgressDialogState();
}

class _LevelProgressDialogState extends ConsumerState<LevelProgressDialog> {
  // null = "Nivel neatribuit"
  String? _level;
  int? _progress;
  late final TextEditingController _progressCtl;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _level = widget.initialLevel;
    _progress = widget.initialProgress;
    _progressCtl = TextEditingController(
      text: widget.initialProgress?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _progressCtl.dispose();
    super.dispose();
  }

  bool get _progressValid =>
      _progress == null || (_progress! >= 0 && _progress! <= 100);

  bool get _canSave => !_saving && _progressValid;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(childrenRepositoryProvider)
          .setLearningLevel(
            childId: widget.childId,
            currentLevel: _level,
            levelProgress: _progress,
          );
      if (!mounted) return;
      // Refresh the child details page only — the children list grid
      // does not render these two fields today, so a full
      // `allChildrenProvider` invalidate would be wasted work.
      ref.invalidate(childByIdProvider(widget.childId));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Parcurs TTH] setLearningLevel failed: $e');
      }
      if (!mounted) return;
      setState(() {
        _error = 'Eroare la salvare: $e';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text(
        'Parcurs TTH',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.childFullName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Nivel curent',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String?>(
              initialValue: _level,
              isExpanded: true,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Nivel neatribuit'),
                ),
                ...LearningLevel.values.map(
                  (lv) => DropdownMenuItem<String?>(
                    value: lv.value,
                    child: Text(lv.value),
                  ),
                ),
              ],
              onChanged: _saving ? null : (v) => setState(() => _level = v),
            ),
            const SizedBox(height: 16),
            Text(
              'Progres nivel (0–100)',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _progressCtl,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              decoration: InputDecoration(
                isDense: true,
                border: const OutlineInputBorder(),
                hintText: 'Neatribuit',
                suffixText: '%',
                errorText: _progressValid
                    ? null
                    : 'Introdu un număr între 0 și 100.',
              ),
              onChanged: (raw) {
                final trimmed = raw.trim();
                setState(() {
                  if (trimmed.isEmpty) {
                    _progress = null;
                  } else {
                    _progress = int.tryParse(trimmed);
                  }
                });
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Anulează'),
        ),
        FilledButton(
          onPressed: _canSave ? _save : null,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Salvează'),
        ),
      ],
    );
  }
}
