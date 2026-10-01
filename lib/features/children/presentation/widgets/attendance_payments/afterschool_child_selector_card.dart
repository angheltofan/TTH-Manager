import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/date_utils.dart';
import '../../../../../core/widgets/selector_card_shell.dart';
import '../../../../afterschool/domain/afterschool_program.dart';
import '../../../../afterschool/providers/afterschool_providers.dart';

/// Left-column selector card for an Afterschool program on the child
/// profile — **attendance only**. The month name + ratio is the whole
/// financial-free summary; no payment pill, no fee, no POS/OP info.
class AfterschoolChildSelectorCard extends ConsumerWidget {
  const AfterschoolChildSelectorCard({
    super.key,
    required this.childId,
    required this.program,
    required this.viewedYear,
    required this.viewedMonth,
    required this.selected,
    required this.onTap,
  });

  final String childId;
  final AfterschoolProgram program;
  final int viewedYear;
  final int viewedMonth;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final attendanceAsync = ref.watch(
      afterschoolMonthAttendanceProvider(AfterschoolChildMonthKey(
        childId: childId,
        programId: program.id,
        year: viewedYear,
        month: viewedMonth,
      )),
    );
    final att = attendanceAsync.valueOrNull;
    final ratio = att == null ? '—' : '${att.present} / ${att.expected}';

    return SelectorCardShell(
      selected: selected,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            program.name,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            _monthLabel(viewedYear, viewedMonth),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$ratio prezențe',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (att != null && att.lastPresenceDate != null) ...[
            const SizedBox(height: 8),
            Text(
              'Ultima prezență: ${formatDate(att.lastPresenceDate!)}',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _monthLabel(int year, int month) {
  const months = [
    'ianuarie', 'februarie', 'martie', 'aprilie', 'mai', 'iunie',
    'iulie', 'august', 'septembrie', 'octombrie', 'noiembrie', 'decembrie',
  ];
  final name = months[month - 1];
  final capitalised = name[0].toUpperCase() + name.substring(1);
  return '$capitalised $year';
}
