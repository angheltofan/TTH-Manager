import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/monthly_management_report_provider.dart';
import '../services/monthly_management_pdf_service.dart';

const _monthNames = <String>[
  'ianuarie', 'februarie', 'martie', 'aprilie', 'mai', 'iunie',
  'iulie', 'august', 'septembrie', 'octombrie', 'noiembrie', 'decembrie',
];

/// Opens the month/year picker. On confirm the report is fetched, the
/// PDF is built, and the OS / browser share/save sheet is shown.
Future<void> showMonthlyReportDialog(BuildContext context, WidgetRef ref) async {
  final now = DateTime.now();
  // Default to the previous month if we're in the first week — a more
  // helpful starting point for management-style "what happened last month"
  // queries. Otherwise default to the current month.
  final initialMonth = now.day < 7 && now.month > 1 ? now.month - 1 : now.month;
  final initialYear = now.day < 7 && now.month == 1 ? now.year - 1 : now.year;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _MonthlyReportDialog(
      ref: ref,
      initialYear: initialYear,
      initialMonth: initialMonth,
    ),
  );
}

class _MonthlyReportDialog extends StatefulWidget {
  const _MonthlyReportDialog({
    required this.ref,
    required this.initialYear,
    required this.initialMonth,
  });

  final WidgetRef ref;
  final int initialYear;
  final int initialMonth;

  @override
  State<_MonthlyReportDialog> createState() => _MonthlyReportDialogState();
}

class _MonthlyReportDialogState extends State<_MonthlyReportDialog> {
  late int _year = widget.initialYear;
  late int _month = widget.initialMonth;
  bool _busy = false;
  String? _error;

  Future<void> _generate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = widget.ref
          .read(monthlyManagementReportRepositoryProvider);
      final data = await repo.fetchReport(year: _year, month: _month);
      final bytes =
          await MonthlyManagementPdfService().build(data);
      final fileName = 'raport_managerial_${_year}_'
          '${_month.toString().padLeft(2, '0')}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: fileName);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (kDebugMode) debugPrint('[MonthlyReport] generation failed: $e');
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Raportul nu a putut fi generat. Încearcă din nou.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final years =
        List.generate(5, (i) => now.year - i).toList(); // current + 4 past
    return AlertDialog(
      title: const Text('Raport managerial lunar'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Alege luna pentru care vrei să generezi raportul. '
              'PDF-ul va include date din baza aplicației pentru luna '
              'selectată.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _month,
                    decoration: const InputDecoration(
                      labelText: 'Luna',
                      isDense: true,
                    ),
                    items: [
                      for (var m = 1; m <= 12; m++)
                        DropdownMenuItem(value: m, child: Text(_monthNames[m - 1])),
                    ],
                    onChanged: _busy
                        ? null
                        : (v) {
                            if (v != null) setState(() => _month = v);
                          },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 110,
                  child: DropdownButtonFormField<int>(
                    initialValue: _year,
                    decoration: const InputDecoration(
                      labelText: 'An',
                      isDense: true,
                    ),
                    items: [
                      for (final y in years)
                        DropdownMenuItem(value: y, child: Text('$y')),
                    ],
                    onChanged: _busy
                        ? null
                        : (v) {
                            if (v != null) setState(() => _year = v);
                          },
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Anulează'),
        ),
        FilledButton(
          onPressed: _busy ? null : _generate,
          style: FilledButton.styleFrom(backgroundColor: AppColors.purple),
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Generează PDF'),
        ),
      ],
    );
  }
}
