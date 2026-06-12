import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../providers/child_report_provider.dart';
import '../../services/child_report_pdf_service.dart';

/// AppBar action: generates the child activity PDF on tap.
///
/// Visible only for `admin` and `trainer` roles — parents never see this
/// button. Disabled while a generation is in flight. Errors surface as a
/// friendly snackbar; raw exceptions are kept out of the UI.
class GenerateChildReportButton extends ConsumerStatefulWidget {
  const GenerateChildReportButton({super.key, required this.childId});
  final String childId;

  @override
  ConsumerState<GenerateChildReportButton> createState() =>
      _GenerateChildReportButtonState();
}

class _GenerateChildReportButtonState
    extends ConsumerState<GenerateChildReportButton> {
  bool _busy = false;

  Future<void> _generate() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Se generează raportul...'),
        duration: Duration(seconds: 30),
      ),
    );
    try {
      final repo = ref.read(childReportRepositoryProvider);
      final data = await repo.fetchChildActivityReport(widget.childId);

      final service = ChildReportPdfService();
      final bytes = await service.buildChildActivityReportPdf(data);

      messenger.hideCurrentSnackBar();

      final fileName = _buildFileName(data.childInfo.fullName);
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[ChildReport] generation failed: $e\n$st');
      }
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Raportul nu a putut fi generat. Încercați din nou.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _buildFileName(String childName) {
    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final safe = _slugify(childName);
    return 'raport_activitate_${safe}_$stamp.pdf';
  }

  String _slugify(String input) {
    const map = {
      'ă': 'a', 'â': 'a', 'î': 'i', 'ș': 's', 'ş': 's', 'ț': 't', 'ţ': 't',
      'Ă': 'A', 'Â': 'A', 'Î': 'I', 'Ș': 'S', 'Ş': 'S', 'Ț': 'T', 'Ţ': 'T',
    };
    final buf = StringBuffer();
    for (final ch in input.toLowerCase().split('')) {
      buf.write(map[ch] ?? ch);
    }
    final stripped = buf
        .toString()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return stripped.isEmpty ? 'copil' : stripped;
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final canSee = profile?.isStaff ?? false;
    if (!canSee) return const SizedBox.shrink();

    return IconButton(
      tooltip: 'Generează raport PDF',
      onPressed: _busy ? null : _generate,
      icon: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.purple,
              ),
            )
          : const Icon(
              Icons.picture_as_pdf_outlined,
              color: AppColors.purple,
            ),
    );
  }
}
