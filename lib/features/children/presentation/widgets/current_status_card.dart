import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/error_state.dart';
import '../../providers/child_details_providers.dart';
import 'attendance_row_item.dart';
import 'details_section_card.dart';

class CurrentStatusCard extends ConsumerWidget {
  const CurrentStatusCard({super.key, required this.childId});
  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final statusAsync = ref.watch(childCurrentStatusProvider(childId));
    final rowsAsync = ref.watch(childCurrentStatusRowsProvider(childId));

    Widget content;

    if (rowsAsync.isLoading || statusAsync.isLoading) {
      content = const _InlineLoader();
    } else if (rowsAsync.hasError) {
      content = AppError(message: rowsAsync.error.toString());
    } else {
      final rows = rowsAsync.valueOrNull ?? [];
      final status = statusAsync.valueOrNull;
      // Count present from the actual rows so the X/4 always matches what is shown.
      final presentCount = rows.where((r) => r.attendanceStatus == 'present').length;
      final total = status?.sessionsCount ?? 4;
      final progress = (presentCount / total).clamp(0.0, 1.0);

      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$presentCount / $total prezențe',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.purple.withValues(alpha: 0.12),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.purple),
            ),
          ),
          const SizedBox(height: 16),
          if (rows.isEmpty)
            Text(
              'Nu există încă prezențe în statusul actual.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            )
          else
            Column(
              children: [
                const AttendanceTableHeader(),
                for (int i = 0; i < rows.length; i++)
                  AttendanceRowItem(
                    index: i + 1,
                    workshopTitle: rows[i].workshopTitle ?? '—',
                    dayOfWeek: rows[i].dayOfWeek,
                    workshopDate: rows[i].workshopDate,
                    startTime: rows[i].startTime,
                    endTime: rows[i].endTime,
                    attendanceStatus: rows[i].attendanceStatus,
                    observation: rows[i].observation,
                  ),
              ],
            ),
        ],
      );
    }

    return DetailsSectionCard(
      title: 'Status actual',
      iconData: Icons.show_chart_rounded,
      iconColor: const Color(0xFF14B8A6),
      child: content,
    );
  }
}

class _InlineLoader extends StatelessWidget {
  const _InlineLoader();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
}
