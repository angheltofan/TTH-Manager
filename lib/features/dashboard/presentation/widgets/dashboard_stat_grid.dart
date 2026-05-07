import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/responsive_grid.dart';
import '../../../../core/widgets/stat_card.dart';
import '../../domain/dashboard_stats.dart';

class DashboardStatGrid extends StatelessWidget {
  const DashboardStatGrid({super.key, required this.stats});

  final DashboardStats? stats;

  @override
  Widget build(BuildContext context) {
    if (stats == null) return const SizedBox.shrink();
    final s = stats!;

    return ResponsiveGrid(
      minItemWidth: 200,
      spacing: 14,
      children: [
        StatCard(
          label: 'Copii înscriși',
          value: '${s.totalChildren}',
          icon: Icons.child_care_outlined,
          color: AppColors.purple,
          subLabel: 'Total activi',
        ),
        StatCard(
          label: 'Ateliere azi',
          value: '${s.workshopsToday}',
          icon: Icons.event_note_outlined,
          color: AppColors.info,
          subLabel: 'Programate astăzi',
        ),
        StatCard(
          label: 'Plăți restante',
          value: '${s.pendingPayments}',
          icon: Icons.payments_outlined,
          color: AppColors.warning,
          subLabel: s.pendingPayments > 0 ? 'Necesită atenție' : 'La zi',
          onTap: s.pendingPayments > 0
              ? () => context.push('/payments-due')
              : null,
        ),
        StatCard(
          label: 'Rată prezență',
          value: '${s.attendanceRate.toStringAsFixed(0)}%',
          icon: Icons.checklist_rounded,
          color: AppColors.success,
          subLabel: 'Ultimele 30 de zile',
        ),
      ],
    );
  }
}

