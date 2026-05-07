import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class AttendanceDialog extends StatefulWidget {
  const AttendanceDialog({
    super.key,
    required this.initialStatus,
    this.currentObs,
    required this.onSave,
  });

  final String initialStatus;
  final String? currentObs;
  final void Function(String status, String? observation) onSave;

  @override
  State<AttendanceDialog> createState() => _AttendanceDialogState();
}

class _AttendanceDialogState extends State<AttendanceDialog> {
  late String _status;
  late final TextEditingController _obsCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    _obsCtrl = TextEditingController(text: widget.currentObs ?? '');
  }

  @override
  void dispose() {
    _obsCtrl.dispose();
    super.dispose();
  }

  void _save() {
    setState(() => _saving = true);
    final obs = _obsCtrl.text.trim();
    widget.onSave(_status, obs.isEmpty ? null : obs);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Marchează prezența'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _DialogStatusBtn(
                  label: 'Prezent',
                  icon: Icons.check_rounded,
                  selected: _status == 'present',
                  color: AppColors.success,
                  onTap: () => setState(() => _status = 'present'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DialogStatusBtn(
                  label: 'Absent',
                  icon: Icons.close_rounded,
                  selected: _status == 'absent',
                  color: AppColors.error,
                  onTap: () => setState(() => _status = 'absent'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _obsCtrl,
            decoration: const InputDecoration(
              labelText: 'Observație (opțional)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Anulează'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Salvează'),
        ),
      ],
    );
  }
}

class _DialogStatusBtn extends StatelessWidget {
  const _DialogStatusBtn({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
