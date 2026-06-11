import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/responsive_grid.dart';
import '../../../../core/widgets/stat_card.dart';
import '../../domain/parent_dashboard.dart';
import '../../utils/parent_date_labels.dart';

/// Four-up KPI grid on the parent dashboard.
///
/// Renders identical [StatCard] cells to the staff dashboard's
/// `DashboardStatGrid`, with `dense: true` so the longer parent
/// strings ("Vineri, 29 mai", "În regulă", "1 restantă") fit at 4-col
/// on tablet without truncation. KPI values stay at `w700` so the
/// visual weight matches staff exactly.
class ParentKpiGrid extends ConsumerWidget {
  const ParentKpiGrid({
    super.key,
    required this.children,
    required this.nextWorkshopAsync,
    required this.attendanceRateAsync,
    required this.paymentSummaryAsync,
  });

  final List<ParentDashboardChild> children;
  final AsyncValue<ParentNextWorkshopSummary?> nextWorkshopAsync;
  final AsyncValue<ParentAttendanceRateSummary> attendanceRateAsync;
  final AsyncValue<ParentPaymentSummary> paymentSummaryAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        return ResponsiveGrid(
          minItemWidth: isMobile ? 130 : 200,
          spacing: isMobile ? 10 : 14,
          children: [
            _enrolledCard(),
            _nextWorkshopCard(),
            _attendanceRateCard(),
            _paymentCard(),
          ],
        );
      },
    );
  }

  // ── 1. Copii înscriși ──────────────────────────────────────────────────────

  Widget _enrolledCard() {
    final count = children.length;
    final subLabel = count == 0
        ? '0 activi'
        : (count == 1 ? '1 activ' : '$count activi');
    return StatCard(
      label: 'Copii înscriși',
      value: '$count',
      icon: Icons.groups_outlined,
      color: AppColors.purple,
      subLabel: subLabel,
      dense: true,
    );
  }

  // ── 2. Următorul atelier (parent-level: across ALL children) ──────────────

  Widget _nextWorkshopCard() {
    return nextWorkshopAsync.when(
      loading: () => const StatCard(
        label: 'Următorul atelier',
        value: '…',
        icon: Icons.event_note_outlined,
        color: AppColors.info,
        subLabel: 'Se încarcă',
        dense: true,
      ),
      error: (_, _) => const StatCard(
        label: 'Următorul atelier',
        value: '—',
        icon: Icons.event_note_outlined,
        color: AppColors.info,
        subLabel: 'Eroare la încărcare',
        dense: true,
      ),
      data: (next) {
        if (next == null) {
          return const StatCard(
            label: 'Următorul atelier',
            value: 'Niciun atelier',
            icon: Icons.event_note_outlined,
            color: AppColors.info,
            subLabel: 'Nu există sesiuni programate',
            dense: true,
          );
        }

        final date = next.workshopDate;
        final timePart = _timeRange(next.startTime, next.endTime);
        final names = next.childNames;
        final hasMultipleChildren = children.length > 1;

        final value = date != null
            ? formatRoFullDay(date)
            : (next.dayOfWeek?.isNotEmpty == true
                ? next.dayOfWeek!
                : next.displayLabel);

        final tail = hasMultipleChildren && names.isNotEmpty
            ? names.join(', ')
            : next.displayLabel;
        final parts = <String>[
          if (timePart.isNotEmpty) timePart,
          if (tail.isNotEmpty) tail,
        ];
        final addCount = next.additionalUpcomingCount;
        var subLabel = parts.join(' · ');
        if (addCount > 0) {
          final suffix = '+ încă $addCount '
              '${addCount == 1 ? "atelier" : "ateliere"}';
          subLabel = subLabel.isEmpty ? suffix : '$subLabel · $suffix';
        }
        if (subLabel.isEmpty) subLabel = 'Programat';

        return StatCard(
          label: 'Următorul atelier',
          value: value,
          icon: Icons.event_note_outlined,
          color: AppColors.info,
          subLabel: subLabel,
          dense: true,
        );
      },
    );
  }

  // ── 3. Rată prezență (last 30 days, all linked children) ──────────────────

  Widget _attendanceRateCard() {
    return attendanceRateAsync.when(
      loading: () => const StatCard(
        label: 'Rată prezență',
        value: '…',
        icon: Icons.checklist_rounded,
        color: AppColors.success,
        subLabel: 'Se încarcă',
        dense: true,
      ),
      error: (_, _) => const StatCard(
        label: 'Rată prezență',
        value: '—',
        icon: Icons.checklist_rounded,
        color: AppColors.success,
        subLabel: 'Eroare la încărcare',
        dense: true,
      ),
      data: (summary) {
        if (summary.isEmpty) {
          return const StatCard(
            label: 'Rată prezență',
            value: '—',
            icon: Icons.checklist_rounded,
            color: AppColors.success,
            subLabel: 'Fără date recente',
            dense: true,
          );
        }
        final pct = summary.ratePercent ?? 0;
        final missed = summary.missedCount;
        final subLabel =
            '${summary.presentCount} prezențe · $missed absențe';
        return StatCard(
          label: 'Rată prezență',
          value: '${pct.toStringAsFixed(0)}%',
          icon: Icons.checklist_rounded,
          color: AppColors.success,
          subLabel: subLabel,
          dense: true,
        );
      },
    );
  }

  // ── 4. Plăți (overdue > due > ok) ─────────────────────────────────────────

  Widget _paymentCard() {
    return paymentSummaryAsync.when(
      loading: () => const StatCard(
        label: 'Plăți',
        value: '…',
        icon: Icons.payments_outlined,
        color: AppColors.warning,
        subLabel: 'Se încarcă',
        dense: true,
      ),
      error: (_, _) => const StatCard(
        label: 'Plăți',
        value: '—',
        icon: Icons.payments_outlined,
        color: AppColors.warning,
        subLabel: 'Eroare la încărcare',
        dense: true,
      ),
      data: (summary) {
        switch (summary.status) {
          case ParentPaymentSummaryStatus.overdue:
            final n = summary.overdueCount;
            return StatCard(
              label: 'Plăți',
              value: n == 1 ? '1 restantă' : '$n restante',
              icon: Icons.payments_outlined,
              color: AppColors.error,
              subLabel: _namesOr(
                summary.affectedChildFirstNames,
                fallback: 'Plată restantă',
              ),
              dense: true,
            );
          case ParentPaymentSummaryStatus.due:
            final n = summary.dueCount;
            return StatCard(
              label: 'Plăți',
              value: n == 1 ? '1 de plătit' : '$n de plătit',
              icon: Icons.payments_outlined,
              color: AppColors.warning,
              subLabel: _namesOr(
                summary.affectedChildFirstNames,
                fallback: 'Confirmă plata',
              ),
              dense: true,
            );
          case ParentPaymentSummaryStatus.ok:
            return const StatCard(
              label: 'Plăți',
              value: 'În regulă',
              icon: Icons.payments_outlined,
              color: AppColors.success,
              subLabel: 'Nicio plată restantă',
              dense: true,
            );
        }
      },
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _timeRange(String? start, String? end) {
    final s = start != null ? formatTimeString(start) : '';
    final e = end != null ? formatTimeString(end) : '';
    if (s.isEmpty) return '';
    if (e.isEmpty) return s;
    return '$s - $e';
  }

  static String _namesOr(List<String> names, {required String fallback}) {
    final cleaned = names.where((n) => n.trim().isNotEmpty).toList();
    if (cleaned.isEmpty) return fallback;
    return cleaned.join(', ');
  }
}
