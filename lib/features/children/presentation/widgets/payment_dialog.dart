import 'package:flutter/material.dart';

/// Shows a modal dialog for selecting the payment method (POS / OP).
///
/// Returns the selected method string on success, or [null] if the user
/// cancelled or an error occurred (the dialog shows its own inline error).
Future<String?> showPaymentMethodDialog(
  BuildContext context, {
  required Future<void> Function(String method) onConfirm,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PaymentDialog(onConfirm: onConfirm),
  );
}

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({required this.onConfirm});
  final Future<void> Function(String method) onConfirm;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  String _selected = 'POS';
  bool _loading = false;
  String? _errorText;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirmare plată'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Alege metoda de plată.'),
          const SizedBox(height: 8),
          RadioListTile<String>(
            value: 'POS',
            groupValue: _selected,
            title: const Text('POS'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            onChanged: _loading ? null : (v) => setState(() => _selected = v!),
          ),
          RadioListTile<String>(
            value: 'OP',
            groupValue: _selected,
            title: const Text('OP'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            onChanged: _loading ? null : (v) => setState(() => _selected = v!),
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorText!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ],
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
      await widget.onConfirm(_selected);
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
