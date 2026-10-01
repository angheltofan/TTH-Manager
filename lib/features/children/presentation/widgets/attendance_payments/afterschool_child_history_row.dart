import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/widgets/status_pill.dart';
import '../../../../afterschool/domain/afterschool_program.dart';
import '../../../../afterschool/providers/afterschool_providers.dart';

/// One historical row inside the "Istoric" tab for an Afterschool
/// program — **attendance only**. Afterschool does not have payment
/// semantics on the child profile, so this row never renders a
/// payment pill, nor a materialize/cancel/reopen action.
///
/// The month label + attendance ratio are the primary content. Expand
/// to see the breakdown + unexpected marks when any.
class AfterschoolChildHistoryRow extends ConsumerStatefulWidget {
  const AfterschoolChildHistoryRow({
    super.key,
    required this.childId,
    required this.program,
    required this.year,
    required this.month,
  });

  final String childId;
  final AfterschoolProgram program;
  final int year;
  final int month;

  @override
  ConsumerState<AfterschoolChildHistoryRow> createState() =>
      _AfterschoolChildHistoryRowState();
}

class _AfterschoolChildHistoryRowState
    extends ConsumerState<AfterschoolChildHistoryRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final attendanceAsync = ref.watch(
      afterschoolMonthAttendanceProvider(AfterschoolChildMonthKey(
        childId: widget.childId,
        programId: widget.program.id,
        year: widget.year,
        month: widget.month,
      )),
    );
    final att = attendanceAsync.valueOrNull;
    final ratio = att == null ? '—' : '${att.present} / ${att.expected}';

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _monthLabel(widget.year, widget.month),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$ratio prezențe',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.12),
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (att != null) ...[
                      Text(
                        [
                          if (att.present > 0) '${att.present} prezente',
                          if (att.absent > 0) '${att.absent} absente',
                          if (att.unmarked > 0)
                            att.unmarked == 1
                                ? '1 nemarcată'
                                : '${att.unmarked} nemarcate',
                        ].join(' · '),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (att.unexpected > 0) ...[
                        const SizedBox(height: 6),
                        StatusPill(
                          label: att.unexpected == 1
                              ? '1 prezență în afara programului'
                              : '${att.unexpected} prezențe în afara programului',
                          color: AppColors.warning,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _monthLabel(int year, int month) {
  const long = [
    'ianuarie', 'februarie', 'martie', 'aprilie', 'mai', 'iunie',
    'iulie', 'august', 'septembrie', 'octombrie', 'noiembrie', 'decembrie',
  ];
  final name = long[month - 1];
  final capitalised = name[0].toUpperCase() + name.substring(1);
  return '$capitalised $year';
}
