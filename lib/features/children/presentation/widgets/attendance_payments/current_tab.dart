import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/date_utils.dart';
import '../../../../../core/utils/responsive.dart';
import '../../../../afterschool/domain/afterschool_program.dart';
import '../../../../afterschool/providers/afterschool_providers.dart';
import '../../../../auth/providers/auth_providers.dart';
import '../../../providers/child_details_providers.dart';
import '../payment_dialog.dart';
import 'afterschool_child_detail_pane.dart';
import 'afterschool_child_selector_card.dart';
import 'attendance_timeline.dart';
import 'series_snapshot.dart';

/// The default tab: left-column selector of the child's programs
/// (workshop series AND Afterschool programs) + right-column detail
/// pane.
///
/// Layout:
///   • desktop (≥900px): 2-column, 320px selector + Expanded detail
///   • tablet (600-900): single-column with a horizontal chip selector
///   • mobile (<600): dropdown selector + full-width detail
class CurrentTab extends ConsumerStatefulWidget {
  const CurrentTab({
    super.key,
    required this.childId,
    required this.snapshots,
  });

  final String childId;
  final Map<String, SeriesFinancialSnapshot> snapshots;

  @override
  ConsumerState<CurrentTab> createState() => _CurrentTabState();
}

/// Tagged selection so the "right pane" knows which kind of item to
/// render without leaking string-key conventions across widgets.
sealed class _Selection {
  const _Selection();
  String get key;
}

class _WorkshopSelection extends _Selection {
  const _WorkshopSelection(this.seriesId);
  final String seriesId;
  @override
  String get key => 'ws:$seriesId';
}

class _AfterschoolSelection extends _Selection {
  const _AfterschoolSelection(this.programId);
  final String programId;
  @override
  String get key => 'afs:$programId';
}

class _CurrentTabState extends ConsumerState<CurrentTab> {
  _Selection? _selected;
  int? _viewedYear;
  int? _viewedMonth;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    _viewedYear ??= now.year;
    _viewedMonth ??= now.month;

    final workshopItems = widget.snapshots.values.toList()
      ..sort((a, b) => a.seriesTitle.compareTo(b.seriesTitle));

    // Afterschool programs the child is enrolled in (any state — an
    // ended enrollment still shows for historical context).
    final enrollmentsAsync =
        ref.watch(afterschoolEnrollmentsForChildProvider(widget.childId));
    final programsAsync = ref.watch(afterschoolAllProgramsProvider);
    final afterschoolPrograms = _resolveAfterschoolPrograms(
      enrollmentsAsync.valueOrNull ?? const [],
      programsAsync.valueOrNull ?? const [],
    );

    // Pick a default selection: workshop series first, otherwise first
    // Afterschool program.
    if (_selected == null) {
      if (workshopItems.isNotEmpty) {
        _selected = _WorkshopSelection(workshopItems.first.seriesId);
      } else if (afterschoolPrograms.isNotEmpty) {
        _selected = _AfterschoolSelection(afterschoolPrograms.first.id);
      }
    }

    if (workshopItems.isEmpty && afterschoolPrograms.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Copilul nu are ateliere active sau istoric de prezențe.',
            style: TextStyle(color: AppColors.muted),
          ),
        ),
      );
    }

    final width = MediaQuery.of(context).size.width;
    if (width >= 900) {
      return _buildTwoColumn(workshopItems, afterschoolPrograms);
    }
    if (context.isMobile) {
      return _buildMobile(workshopItems, afterschoolPrograms);
    }
    return _buildTablet(workshopItems, afterschoolPrograms);
  }

  List<AfterschoolProgram> _resolveAfterschoolPrograms(
    List<dynamic> enrollments,
    List<AfterschoolProgram> allPrograms,
  ) {
    if (enrollments.isEmpty || allPrograms.isEmpty) return const [];
    final programIds = <String>{
      for (final e in enrollments) e.programId as String,
    };
    final byId = {for (final p in allPrograms) p.id: p};
    final resolved = <AfterschoolProgram>[
      for (final id in programIds)
        if (byId[id] != null) byId[id]!,
    ];
    resolved.sort((a, b) => a.name.compareTo(b.name));
    return resolved;
  }

  void _onSelect(_Selection s) => setState(() => _selected = s);

  Widget _rightPane(
      List<SeriesFinancialSnapshot> workshops,
      List<AfterschoolProgram> afterschool) {
    final sel = _selected;
    if (sel is _AfterschoolSelection) {
      final program = afterschool.firstWhere(
        (p) => p.id == sel.programId,
        orElse: () => afterschool.first,
      );
      final childRow = ref.watch(childByIdProvider(widget.childId)).valueOrNull;
      final childName = childRow?.fullName ?? widget.childId;
      return AfterschoolChildDetailPane(
        // Key on program so switching resets local state cleanly.
        key: ValueKey('afs-detail-${program.id}'),
        childId: widget.childId,
        childName: childName,
        program: program,
        initialYear: _viewedYear!,
        initialMonth: _viewedMonth!,
        onMonthChanged: (y, m) {
          _viewedYear = y;
          _viewedMonth = m;
        },
      );
    }
    // Fallback / workshop:
    if (sel is _WorkshopSelection && workshops.isNotEmpty) {
      final snap = widget.snapshots[sel.seriesId] ?? workshops.first;
      return _DetailPane(childId: widget.childId, snapshot: snap);
    }
    if (workshops.isNotEmpty) {
      return _DetailPane(childId: widget.childId, snapshot: workshops.first);
    }
    // Shouldn't reach here — we returned early on empty state above.
    return const SizedBox.shrink();
  }

  Widget _buildTwoColumn(
      List<SeriesFinancialSnapshot> workshops,
      List<AfterschoolProgram> afterschool) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 320,
          child: _SelectorList(
            childId: widget.childId,
            workshops: workshops,
            afterschool: afterschool,
            selection: _selected,
            viewedYear: _viewedYear!,
            viewedMonth: _viewedMonth!,
            onSelect: _onSelect,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: _rightPane(workshops, afterschool)),
      ],
    );
  }

  Widget _buildTablet(
      List<SeriesFinancialSnapshot> workshops,
      List<AfterschoolProgram> afterschool) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 68,
          child: _ChipSelector(
            workshops: workshops,
            afterschool: afterschool,
            selection: _selected,
            onSelect: _onSelect,
          ),
        ),
        const SizedBox(height: 12),
        _rightPane(workshops, afterschool),
      ],
    );
  }

  Widget _buildMobile(
      List<SeriesFinancialSnapshot> workshops,
      List<AfterschoolProgram> afterschool) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DropdownSelector(
          workshops: workshops,
          afterschool: afterschool,
          selection: _selected,
          onSelect: _onSelect,
        ),
        const SizedBox(height: 12),
        _rightPane(workshops, afterschool),
      ],
    );
  }
}

// ── LEFT COLUMN: selector list ────────────────────────────────────────

class _SelectorList extends StatelessWidget {
  const _SelectorList({
    required this.childId,
    required this.workshops,
    required this.afterschool,
    required this.selection,
    required this.viewedYear,
    required this.viewedMonth,
    required this.onSelect,
  });

  final String childId;
  final List<SeriesFinancialSnapshot> workshops;
  final List<AfterschoolProgram> afterschool;
  final _Selection? selection;
  final int viewedYear;
  final int viewedMonth;
  final ValueChanged<_Selection> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in workshops) ...[
          _SelectorCard(
            snapshot: s,
            selected: selection is _WorkshopSelection &&
                (selection as _WorkshopSelection).seriesId == s.seriesId,
            onTap: () => onSelect(_WorkshopSelection(s.seriesId)),
          ),
          const SizedBox(height: 8),
        ],
        for (final p in afterschool) ...[
          AfterschoolChildSelectorCard(
            childId: childId,
            program: p,
            viewedYear: viewedYear,
            viewedMonth: viewedMonth,
            selected: selection is _AfterschoolSelection &&
                (selection as _AfterschoolSelection).programId == p.id,
            onTap: () => onSelect(_AfterschoolSelection(p.id)),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

// Workshop selector card — kept identical to the pre-integration
// version; the shared SelectorCardShell will be adopted here in a
// later cleanup pass. Marking it deprecated for internal traceability.
class _SelectorCard extends StatelessWidget {
  const _SelectorCard({
    required this.snapshot,
    required this.selected,
    required this.onTap,
  });

  final SeriesFinancialSnapshot snapshot;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastP = snapshot.lastPresentDate;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.purple.withValues(alpha: 0.06)
                : theme.cardTheme.color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppColors.purple
                  : theme.colorScheme.outline.withValues(alpha: 0.2),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                snapshot.seriesTitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                'Ciclu curent',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${snapshot.currentPresentCount} / 4 prezențe',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  PresentProgressDots(
                    presentCount: snapshot.currentPresentCount,
                  ),
                ],
              ),
              if (lastP != null || snapshot.currentBlockClosingSoon) ...[
                const SizedBox(height: 8),
                if (lastP != null)
                  Text(
                    'Ultima prezență: ${formatDate(lastP)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (snapshot.currentBlockClosingSoon) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Următoarea prezență închide ciclul.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.info,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tablet chip selector ──────────────────────────────────────────────

class _ChipSelector extends StatelessWidget {
  const _ChipSelector({
    required this.workshops,
    required this.afterschool,
    required this.selection,
    required this.onSelect,
  });

  final List<SeriesFinancialSnapshot> workshops;
  final List<AfterschoolProgram> afterschool;
  final _Selection? selection;
  final ValueChanged<_Selection> onSelect;

  @override
  Widget build(BuildContext context) {
    final total = workshops.length + afterschool.length;
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: total,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (context, i) {
        if (i < workshops.length) {
          final s = workshops[i];
          final selected = selection is _WorkshopSelection &&
              (selection as _WorkshopSelection).seriesId == s.seriesId;
          return ChoiceChip(
            selected: selected,
            onSelected: (_) => onSelect(_WorkshopSelection(s.seriesId)),
            label: Text(
              '${s.seriesTitle} · ${s.currentPresentCount}/4',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : null,
              ),
            ),
            selectedColor: AppColors.purple,
          );
        }
        final p = afterschool[i - workshops.length];
        final selected = selection is _AfterschoolSelection &&
            (selection as _AfterschoolSelection).programId == p.id;
        return ChoiceChip(
          selected: selected,
          onSelected: (_) => onSelect(_AfterschoolSelection(p.id)),
          label: Text(
            '${p.name} · Afterschool',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : null,
            ),
          ),
          selectedColor: AppColors.purple,
        );
      },
    );
  }
}

// ── Mobile dropdown selector ──────────────────────────────────────────

class _DropdownSelector extends StatelessWidget {
  const _DropdownSelector({
    required this.workshops,
    required this.afterschool,
    required this.selection,
    required this.onSelect,
  });

  final List<SeriesFinancialSnapshot> workshops;
  final List<AfterschoolProgram> afterschool;
  final _Selection? selection;
  final ValueChanged<_Selection> onSelect;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: selection?.key,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Selectează program',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        for (final s in workshops)
          DropdownMenuItem(
            value: 'ws:${s.seriesId}',
            child: Text(
              '${s.seriesTitle} · ${s.currentPresentCount}/4',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        for (final p in afterschool)
          DropdownMenuItem(
            value: 'afs:${p.id}',
            child: Text(
              '${p.name} · Afterschool',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (v) {
        if (v == null) return;
        if (v.startsWith('ws:')) {
          onSelect(_WorkshopSelection(v.substring(3)));
        } else if (v.startsWith('afs:')) {
          onSelect(_AfterschoolSelection(v.substring(4)));
        }
      },
    );
  }
}

// ── RIGHT COLUMN: detail pane (WORKSHOP) ──────────────────────────────

class _DetailPane extends ConsumerWidget {
  const _DetailPane({required this.childId, required this.snapshot});
  final String childId;
  final SeriesFinancialSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final present = snapshot.currentPresentCount;
    // Advance is only meaningful for a series that isn't yet complete.
    // At 4/4 the recalc trigger has already produced a paid/due cycle.
    final canOfferAdvance = !snapshot.hasAdvance && present < 4;
    final statusLabel = snapshot.hasAdvance
        ? 'Plătit în avans · $present/4'
        : present >= 4
            ? 'Complet · așteaptă plată'
            : present == 0
                ? 'În desfășurare'
                : 'În desfășurare · $present/4';

    // Fetch the child once so the advance button can hide for free
    // participants (their trigger silently blocks payment_cycle
    // inserts, so exposing the button would show a UX no-op).
    final child = ref.watch(childByIdProvider(childId)).valueOrNull;
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final showAdvanceAction = canOfferAdvance &&
        (profile?.isStaff ?? false) &&
        (child != null && !child.isFreeParticipant);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            snapshot.seriesTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text('Ciclu curent',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                  )),
              const SizedBox(width: 8),
              _StatusChip(text: statusLabel),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '$present / 4 prezențe',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 12),
              PresentProgressDots(presentCount: present),
              const Spacer(),
              if (snapshot.hasAdvance)
                _AdvanceBadge(cycle: snapshot.advanceCycle!)
              else if (showAdvanceAction)
                _MarkAdvanceButton(
                  childId: childId,
                  seriesId: snapshot.seriesId,
                ),
            ],
          ),
          if (snapshot.currentBlock.isNotEmpty) ...[
            const SizedBox(height: 16),
            AttendanceTimeline(rows: snapshot.currentBlock),
          ] else ...[
            const SizedBox(height: 12),
            Text(
              'Ciclul curent nu are încă prezențe marcate.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (snapshot.allCycles.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Cicluri finalizate',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 8),
            for (var i = snapshot.allCycles.length - 1; i >= 0; i--) ...[
              CompletedCycleAccordion(
                childId: childId,
                snapshot: snapshot,
                cycleIndex: i,
                cycleNumber: i + 1,
              ),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.info,
        ),
      ),
    );
  }
}

class _AdvanceBadge extends StatelessWidget {
  const _AdvanceBadge({required this.cycle});
  final dynamic cycle;
  @override
  Widget build(BuildContext context) {
    final method = (cycle.paymentMethod as String?)?.toUpperCase();
    final label = method != null && method.isNotEmpty
        ? 'Achitat în avans · $method'
        : 'Achitat în avans';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.info,
        ),
      ),
    );
  }
}

/// Compact action button that opens the standard payment method dialog
/// (POS / OP + optional note) and, on confirmation, calls the existing
/// `markAdvancePayment` RPC scoped to (child, series). Restores the
/// pre-refactor advance-payment flow that lived on the old
/// `ActiveCycleSection`; visibility rules match the current confirm-a-
/// due-cycle button (staff role, non-free child), added by
/// `_DetailPane` before instantiating this widget.
class _MarkAdvanceButton extends ConsumerStatefulWidget {
  const _MarkAdvanceButton({
    required this.childId,
    required this.seriesId,
  });

  final String childId;
  final String seriesId;

  @override
  ConsumerState<_MarkAdvanceButton> createState() =>
      _MarkAdvanceButtonState();
}

class _MarkAdvanceButtonState extends ConsumerState<_MarkAdvanceButton> {
  bool _loading = false;

  Future<void> _onTap() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await showPaymentMethodDialog(
        context,
        onConfirm: (method, observation) async {
          await ref
              .read(childDetailsRepositoryProvider)
              .markAdvancePayment(
                childId: widget.childId,
                seriesId: widget.seriesId,
                // Existing convention (see CompletedCycleAccordion._confirm
                // + payment_dialog.dart): dialog returns 'POS' / 'OP' but
                // the repository writes the lower-case token so the cycle
                // row matches the schema.
                paymentMethod: method.toLowerCase(),
                notes: observation ?? '',
              );
        },
      );
      // Local invalidation for instant feedback. Realtime
      // rt:payment_cycles will fire from the RPC insert and re-cover
      // the same providers a moment later — harmless overlap.
      if (mounted) {
        ref.invalidate(childPaymentCyclesNewProvider(widget.childId));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: _loading ? null : _onTap,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.info,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      icon: _loading
          ? const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.credit_card_rounded, size: 14),
      label: const Text(
        'Marchează plătit',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ── Completed cycle accordion ─────────────────────────────────────────

class CompletedCycleAccordion extends ConsumerStatefulWidget {
  const CompletedCycleAccordion({
    super.key,
    required this.childId,
    required this.snapshot,
    required this.cycleIndex,
    required this.cycleNumber,
  });

  final String childId;
  final SeriesFinancialSnapshot snapshot;
  final int cycleIndex;
  final int cycleNumber;

  @override
  ConsumerState<CompletedCycleAccordion> createState() =>
      _CompletedCycleAccordionState();
}

class _CompletedCycleAccordionState
    extends ConsumerState<CompletedCycleAccordion> {
  bool _expanded = false;
  bool _confirming = false;

  @override
  Widget build(BuildContext context) {
    final cycle = widget.snapshot.allCycles[widget.cycleIndex];
    final rows = widget.snapshot.rowsForCycle(cycle.id);
    final theme = Theme.of(context);

    final (statusColor, statusLabel) = switch (cycle.status) {
      'paid' => (AppColors.success, 'Achitat'),
      'due' => (AppColors.warning, 'De plată'),
      'overdue' => (AppColors.error, 'Restant'),
      'cancelled' => (AppColors.muted, 'Anulat'),
      _ => (AppColors.muted, cycle.status ?? '—'),
    };

    final period = (cycle.periodStart != null && cycle.periodEnd != null)
        ? '${formatDate(cycle.periodStart!)} – ${formatDate(cycle.periodEnd!)}'
        : '—';
    final presCount = widget.snapshot.presencesInCycle(cycle.id);
    final absCount = widget.snapshot.absencesInCycle(cycle.id);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
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
                        Row(
                          children: [
                            Text(
                              'Ciclul #${widget.cycleNumber}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: statusColor.withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$period · $presCount prezențe'
                          '${absCount > 0 ? ", $absCount absențe" : ""}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (cycle.paidAt != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Achitat la ${formatDate(cycle.paidAt!)}'
                            '${cycle.paymentMethod != null ? " · ${cycle.paymentMethod!.toUpperCase()}" : ""}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.success,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (cycle.status == 'due' || cycle.status == 'overdue')
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: FilledButton(
                        onPressed: _confirming
                            ? null
                            : () => _confirm(cycle.id),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: _confirming
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'Confirmă plata',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700),
                              ),
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
                padding: const EdgeInsets.only(top: 12),
                child: AttendanceTimeline(rows: rows, compact: true),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirm(String cycleId) async {
    final authUser = ref.read(currentUserProvider);
    if (authUser == null) return;
    final isStaff =
        ref.read(currentProfileProvider).valueOrNull?.isStaff ?? false;
    setState(() => _confirming = true);
    try {
      await showPaymentMethodDialog(
        context,
        onConfirm: (method, observation) async {
          await ref
              .read(childDetailsRepositoryProvider)
              .confirmPayment(
                isStaff: isStaff,
                cycleId: cycleId,
                userId: authUser.id,
                paymentMethod: method.toLowerCase(),
                notes: observation ?? '',
              );
        },
      );
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }
}
