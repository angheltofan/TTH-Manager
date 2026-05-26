import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/responsive.dart';
import '../domain/parent_dashboard.dart';
import '../providers/parent_dashboard_providers.dart';
import '../utils/parent_status_labels.dart';
import 'widgets/parent_section_card.dart';

/// Strictly read-only Child Details page for the parent role. Does not
/// reuse the staff Child Details page so we don't accidentally surface
/// any mutation affordances or admin-scoped data (notes, etc.).
class ParentChildDetailsPage extends ConsumerWidget {
  const ParentChildDetailsPage({super.key, required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final basicAsync = ref.watch(parentChildBasicProvider(childId));
    final workshopsAsync = ref.watch(parentActiveWorkshopsProvider(childId));
    final cyclesAsync = ref.watch(parentChildPaymentCyclesProvider(childId));
    final nextAsync = ref.watch(parentNextWorkshopProvider(childId));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/parent'),
        ),
        title: const Text('Detalii copil'),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: basicAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (e, _) {
              if (kDebugMode) debugPrint('[Parent/Child] load failed: $e');
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'A apărut o eroare. Încearcă din nou.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.error),
                  ),
                ),
              );
            },
            data: (basic) {
              if (basic == null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Copilul nu a fost găsit.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                );
              }
              return SingleChildScrollView(
                padding: context.mobilePadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _BasicCard(data: basic),
                    SizedBox(height: context.sectionGap),
                    _WorkshopsCard(workshopsAsync: workshopsAsync),
                    SizedBox(height: context.sectionGap),
                    _NextWorkshopCard(nextAsync: nextAsync),
                    SizedBox(height: context.sectionGap),
                    _PaymentHistoryCard(cyclesAsync: cyclesAsync),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Basic info ────────────────────────────────────────────────────────────────

class _BasicCard extends StatelessWidget {
  const _BasicCard({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = (data['first_name'] as String?) ?? '';
    final last = (data['last_name'] as String?) ?? '';
    final fullName = '$first $last'.trim();
    final birthRaw = data['birth_date'] as String?;
    final birth = birthRaw != null ? DateTime.tryParse(birthRaw) : null;
    return ParentSectionCard(
      title: 'Date copil',
      icon: Icons.person_rounded,
      iconColor: const Color(0xFFEC4899),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fullName.isEmpty ? '(fără nume)' : fullName,
            style: theme.textTheme.bodyLarge
                ?.copyWith(fontWeight: FontWeight.w700),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (birth != null) ...[
            const SizedBox(height: 6),
            Text(
              'Data nașterii: ${formatDateLong(birth)}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Active workshops ──────────────────────────────────────────────────────────

class _WorkshopsCard extends StatelessWidget {
  const _WorkshopsCard({required this.workshopsAsync});
  final AsyncValue<List<ParentNextWorkshop>> workshopsAsync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ParentSectionCard(
      title: 'Atelierele copilului',
      icon: Icons.school_rounded,
      iconColor: const Color(0xFF8B5CF6),
      child: workshopsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (e, _) => Text(
          'Eroare la încărcare.',
          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.error),
        ),
        data: (workshops) {
          if (workshops.isEmpty) {
            return Text(
              'Niciun atelier activ.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < workshops.length; i++) ...[
                if (i > 0) const Divider(height: 20),
                _WorkshopRow(workshop: workshops[i]),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _WorkshopRow extends StatelessWidget {
  const _WorkshopRow({required this.workshop});
  final ParentNextWorkshop workshop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final startLabel = workshop.startTime != null
        ? formatTimeString(workshop.startTime!)
        : '';
    final endLabel =
        workshop.endTime != null ? formatTimeString(workshop.endTime!) : '';
    final timeRange = startLabel.isEmpty
        ? ''
        : (endLabel.isEmpty ? startLabel : '$startLabel – $endLabel');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          workshop.title?.isNotEmpty == true
              ? workshop.title!
              : (workshop.workshopType ?? 'Atelier'),
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w700),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            if (workshop.dayOfWeek != null && workshop.dayOfWeek!.isNotEmpty)
              _MetaChip(
                icon: Icons.calendar_today_outlined,
                label: workshop.dayOfWeek!,
              ),
            if (timeRange.isNotEmpty)
              _MetaChip(icon: Icons.schedule_outlined, label: timeRange),
          ],
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: theme.colorScheme.outline),
      const SizedBox(width: 4),
      Text(
        label,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.outline),
      ),
    ]);
  }
}

// ── Next workshop ─────────────────────────────────────────────────────────────

class _NextWorkshopCard extends StatelessWidget {
  const _NextWorkshopCard({required this.nextAsync});
  final AsyncValue<ParentNextWorkshop?> nextAsync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ParentSectionCard(
      title: 'Următoarea sesiune',
      icon: Icons.event_rounded,
      iconColor: const Color(0xFF3B82F6),
      child: nextAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (e, _) => Text(
          'Eroare la încărcare.',
          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.error),
        ),
        data: (workshop) {
          if (workshop == null) {
            return Text(
              'Nu există nicio sesiune programată.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            );
          }
          final dateLabel = workshop.workshopDate != null
              ? formatDateLong(workshop.workshopDate!)
              : '—';
          final startLabel = workshop.startTime != null
              ? formatTimeString(workshop.startTime!)
              : '';
          final endLabel = workshop.endTime != null
              ? formatTimeString(workshop.endTime!)
              : '';
          final time = startLabel.isEmpty
              ? ''
              : (endLabel.isEmpty ? startLabel : '$startLabel – $endLabel');
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                workshop.title?.isNotEmpty == true
                    ? workshop.title!
                    : (workshop.workshopType ?? 'Atelier'),
                style: theme.textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                dateLabel,
                style: theme.textTheme.bodySmall,
              ),
              if (time.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(time, style: theme.textTheme.bodySmall),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ── Payment history ───────────────────────────────────────────────────────────

class _PaymentHistoryCard extends StatelessWidget {
  const _PaymentHistoryCard({required this.cyclesAsync});
  final AsyncValue<List<Map<String, dynamic>>> cyclesAsync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ParentSectionCard(
      title: 'Istoric plăți',
      icon: Icons.credit_card_rounded,
      iconColor: const Color(0xFF10B981),
      child: cyclesAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (e, _) => Text(
          'Eroare la încărcare.',
          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.error),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return Text(
              'Niciun ciclu de plată înregistrat.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const Divider(height: 20),
                _CycleRow(row: rows[i]),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _CycleRow extends StatelessWidget {
  const _CycleRow({required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = row['status'] as String?;
    final paidAtRaw = row['paid_at'] as String?;
    final startRaw = row['period_start'] as String?;
    final endRaw = row['period_end'] as String?;
    final paidAt = paidAtRaw != null ? DateTime.tryParse(paidAtRaw) : null;
    final start = startRaw != null ? DateTime.tryParse(startRaw) : null;
    final end = endRaw != null ? DateTime.tryParse(endRaw) : null;
    final period = (start != null && end != null)
        ? '${formatDate(start)} – ${formatDate(end)}'
        : (start != null
            ? formatDate(start)
            : (end != null ? formatDate(end) : ''));
    final color = parentPaymentColor(status);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: (color ?? theme.colorScheme.outline)
                .withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            parentPaymentLabel(status),
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (period.isNotEmpty)
                Text(period,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              if (paidAt != null) ...[
                const SizedBox(height: 2),
                Text('Plătit pe ${formatDate(paidAt)}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

