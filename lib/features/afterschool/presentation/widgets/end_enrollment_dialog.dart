import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/afterschool_enrollment.dart';
import '../../domain/afterschool_program.dart';
import '../../providers/afterschool_providers.dart';

/// End an enrollment (sets `enrolled_until = <picked date>`, `is_active
/// = false`). History rows are preserved for reports. Admin-only.
Future<void> showEndEnrollmentDialog({
  required BuildContext context,
  required WidgetRef ref,
  required AfterschoolProgram program,
  required AfterschoolEnrollment enrollment,
  required String childName,
}) async {
  DateTime picked = _today();
  bool saving = false;
  String? err;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      final theme = Theme.of(ctx);
      return AlertDialog(
        title: Text('Încheie înscrierea · $childName'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Înscrierea va fi marcată încheiată la data selectată. '
                'Istoricul rămâne disponibil pentru rapoarte.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  final p = await showDatePicker(
                    context: ctx,
                    firstDate: enrollment.enrolledFrom,
                    lastDate: DateTime(2100, 12, 31),
                    initialDate:
                        picked.isBefore(enrollment.enrolledFrom)
                            ? enrollment.enrolledFrom
                            : picked,
                  );
                  if (p != null) {
                    setState(
                        () => picked = DateTime(p.year, p.month, p.day));
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: theme.colorScheme.outline
                            .withValues(alpha: 0.4)),
                  ),
                  child: Row(children: [
                    Icon(Icons.event_busy,
                        size: 18, color: theme.colorScheme.outline),
                    const SizedBox(width: 8),
                    Text(
                        'Încheiată la '
                        '${picked.day.toString().padLeft(2, '0')}.'
                        '${picked.month.toString().padLeft(2, '0')}.'
                        '${picked.year}'),
                  ]),
                ),
              ),
              if (err != null) ...[
                const SizedBox(height: 10),
                Text(err!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.error)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed:
                  saving ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Renunță')),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            icon: saving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.event_busy),
            label: const Text('Încheie înscrierea'),
            onPressed: saving
                ? null
                : () async {
                    setState(() {
                      saving = true;
                      err = null;
                    });
                    try {
                      await ref
                          .read(afterschoolEnrollmentsRepositoryProvider)
                          .endEnrollment(
                            isAdmin: true,
                            enrollmentId: enrollment.id,
                            until: picked,
                          );
                      ref.invalidate(
                          afterschoolActiveEnrollmentsForProgramProvider(
                              program.id));
                      ref.invalidate(
                          afterschoolActiveEnrollmentCountProvider(
                              program.id));
                      if (ctx.mounted) {
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: Text(
                                'Înscrierea lui $childName a fost încheiată')));
                      }
                    } catch (e) {
                      setState(() {
                        saving = false;
                        err = e.toString();
                      });
                    }
                  },
          ),
        ],
      );
    }),
  );
}

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}
