import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/responsive_grid.dart';
import '../../../../core/widgets/stat_card.dart';
import '../../domain/parent_dashboard.dart';

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
            value: '—',
            icon: Icons.event_note_outlined,
            color: AppColors.info,
            subLabel: 'Niciun atelier programat',
            dense: true,
          );
        }

        // Layout matches the other three KPI cards 1-for-1 so all four
        // share the same height — the previous optional 3rd line (the
        // workshop title) made this card taller than its siblings and
        // broke the grid row alignment on mobile. The workshop name is
        // already visible in the "Copiii mei" cards below, so removing
        // it from the KPI loses no information.
        //
        //   value    → short weekday name ("Luni")  ← always 1 word
        //   subLabel → time range ("17:30 – 19:00") ← always short
        final date = next.workshopDate;
        final timePart = _timeRange(next.startTime, next.endTime);

        final value = date != null
            ? _shortRoWeekday(date)
            : (next.dayOfWeek?.isNotEmpty == true
                ? next.dayOfWeek!
                : next.displayLabel);

        final subLabel = timePart.isNotEmpty ? timePart : 'Programat';

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

  /// Short weekday name in Romanian ("Luni", "Marți", …). Pulled inline
  /// so the parent grid doesn't need a new exported util.
  static const _kRoWeekdayFull = <String>[
    'Luni', 'Marți', 'Miercuri', 'Joi', 'Vineri', 'Sâmbătă', 'Duminică',
  ];
  static String _shortRoWeekday(DateTime date) =>
      _kRoWeekdayFull[(date.weekday - 1).clamp(0, 6)];

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
        // Shorter Romanian: "5 prez. · 1 abs." fits in a 130-px compact
        // card without ellipsis even on the narrowest iPhone width.
        final subLabel =
            '${summary.presentCount} prez. · $missed abs.';
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
              subLabel: 'Fără restanțe',
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
    return '$s – $e';
  }

  static String _namesOr(List<String> names, {required String fallback}) {
    final cleaned = names.where((n) => n.trim().isNotEmpty).toList();
    if (cleaned.isEmpty) return fallback;
    return cleaned.join(', ');
  }
}
