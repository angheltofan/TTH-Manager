import 'package:flutter/material.dart';

/// Shows a modal dialog for confirming a payment.
///
/// The admin picks a payment method (POS / OP) and may optionally add
/// free-text observations. The observations are forwarded verbatim to
/// the caller; an empty/whitespace-only field is normalised to `null`
/// so the repository writes `null` into the notes column.
///
/// Returns the selected method string on success, or `null` if the
/// user cancelled or an error occurred (the dialog shows its own
/// inline error).
Future<String?> showPaymentMethodDialog(
  BuildContext context, {
  required Future<void> Function(String method, String? observation) onConfirm,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PaymentDialog(onConfirm: onConfirm),
  );
}

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({required this.onConfirm});
  final Future<void> Function(String method, String? observation) onConfirm;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  String _selected = 'POS';
  bool _loading = false;
  String? _errorText;
  final _obsCtrl = TextEditingController();

  @override
  void dispose() {
    _obsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Confirmare plată'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Alege metoda de plată.'),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: _selected,
              onChanged: (v) {
                if (_loading || v == null) return;
                setState(() => _selected = v);
              },
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RadioListTile<String>(
                    value: 'POS',
                    title: Text('POS'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  RadioListTile<String>(
                    value: 'OP',
                    title: Text('OP'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _obsCtrl,
              enabled: !_loading,
              minLines: 2,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                labelText: 'Observații',
                hintText: 'Opțional',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorText!,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(null),
          child: const Text('Anulează'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Confirmă'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      final raw = _obsCtrl.text.trim();
      final observation = raw.isEmpty ? null : raw;
      await widget.onConfirm(_selected, observation);
      if (mounted) Navigator.of(context).pop(_selected);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorText = 'Eroare la confirmare. Încearcă din nou.';
        });
      }
    }
  }
}
