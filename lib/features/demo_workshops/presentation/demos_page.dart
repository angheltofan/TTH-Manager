import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/app_search_field.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/status_pill.dart';
import '../../auth/providers/auth_providers.dart';
import '../domain/demo_workshop.dart';
import '../providers/demo_workshops_providers.dart';
import 'widgets/demo_convert_flow.dart';
import 'widgets/reschedule_demo_dialog.dart';

/// Demo-uri — first-class management surface for lead demos.
///
/// Visual chrome aligned to the rest of TTH Manager:
///   • Header follows [ChildrenPageHeader] (42×42 blue icon container,
///     headlineSmall title, muted subtitle, [AppPrimaryButton]).
///   • Compact underline [TabBar] matches the "Situație curentă /
///     Istoric cicluri" strip on the child-details page. Blue
///     accent, text-only tabs with inline count badges.
///   • Search uses the shared [AppSearchField] primitive, same as
///     the Copii page.
///   • Rows are compact scan-friendly entries matching [ChildEntry]
///     on wide screens and stacked cards on mobile. Status is a
///     single shared [StatusPill].
///   • Row actions collapse behind a 3-dot [PopupMenuButton] exactly
///     like the Children list, with inline Prezent/Absent chips kept
///     only on today's actionable row.
///
/// Business logic is unchanged — the same providers, repository
/// methods and `runConvertDemoFlow`/`showRescheduleDemoDialog` are
/// used. Only the presentation layer was rewritten.
class DemosPage extends ConsumerStatefulWidget {
  const DemosPage({super.key});

  @override
  ConsumerState<DemosPage> createState() => _DemosPageState();
}

enum _DemoTab { today, upcoming, history }

class _DemosPageState extends ConsumerState<DemosPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _DemoTab.values.length, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  _DemoTab get _currentTab => _DemoTab.values[_tabs.index];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final isAdmin = profile?.isAdmin ?? false;

    final todayAsync = ref.watch(demosForDayProvider(
      DemosDayKey.fromDate(DateTime.now()),
    ));
    final upcomingAsync = ref.watch(upcomingDemosProvider);
    final historyAsync = ref.watch(historyDemosProvider);

    final currentAsync = switch (_currentTab) {
      _DemoTab.today => todayAsync,
      _DemoTab.upcoming => upcomingAsync,
      _DemoTab.history => historyAsync,
    };

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1000;
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _DemosHeader(isAdmin: isAdmin),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: isWide ? 320 : double.infinity,
                      child: AppSearchField(
                        hint: 'Caută copil, părinte sau telefon...',
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() => _search = v),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _DemosTabBar(
                      controller: _tabs,
                      todayCount: todayAsync.valueOrNull?.length,
                      upcomingCount: upcomingAsync.valueOrNull?.length,
                      historyCount: historyAsync.valueOrNull?.length,
                    ),
                  ]),
                ),
              ),
              currentAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: SizedBox(height: 120, child: AppLoading()),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: AppError(message: e.toString()),
                  ),
                ),
                data: (demos) {
                  final filtered = _applySearch(demos, _search);
                  if (filtered.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(24, 8, 24, 32),
                        child: _EmptyState(
                            tab: _currentTab,
                            hasQuery: _search.isNotEmpty),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        if (isWide) ...[
                          const _DemosTableHeader(),
                          Divider(
                            height: 1,
                            color: theme.colorScheme.outline
                                .withValues(alpha: 0.25),
                          ),
                        ],
                        ListView.separated(
                          shrinkWrap: true,
                          physics:
                              const NeverScrollableScrollPhysics(),
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => Divider(
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                            color: theme.colorScheme.outline
                                .withValues(alpha: 0.18),
                          ),
                          itemBuilder: (_, i) => _DemoEntry(
                            demo: filtered[i],
                            isWide: isWide,
                            isAdmin: isAdmin,
                            tab: _currentTab,
                          ),
                        ),
                      ]),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Pure search filter (also exported for tests) ─────────────────────────────

List<DemoWorkshop> _applySearch(List<DemoWorkshop> demos, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return demos;
  final qDigits = _digitsOnly(q);
  return demos.where((d) {
    final hay = <String>[
      d.childFirstName.toLowerCase(),
      d.childLastName.toLowerCase(),
      '${d.childFirstName} ${d.childLastName}'.toLowerCase(),
      (d.parentName ?? '').toLowerCase(),
      (d.parentPhone ?? '').toLowerCase(),
      (d.parentEmail ?? '').toLowerCase(),
    ];
    final nameHit = hay.any((h) => h.contains(q));
    if (nameHit) return true;
    if (qDigits.isNotEmpty) {
      final phoneDigits = _digitsOnly(d.parentPhone ?? '');
      if (phoneDigits.contains(qDigits)) return true;
    }
    return false;
  }).toList();
}

String _digitsOnly(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

@visibleForTesting
List<DemoWorkshop> applyDemoSearchForTest(
        List<DemoWorkshop> demos, String query) =>
    _applySearch(demos, query);

// ── Header (parity with ChildrenPageHeader) ──────────────────────────────────

class _DemosHeader extends StatelessWidget {
  const _DemosHeader({required this.isAdmin});
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.purple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.rocket_launch_outlined,
              color: AppColors.purple, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Demo-uri',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Gestionează demo-urile și urmărește evoluția lor.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
        if (isAdmin)
          AppPrimaryButton(
            label: 'Programează demo',
            icon: Icons.add_rounded,
            onPressed: () => context.go('/demo-workshops/new'),
          ),
      ],
    );
  }
}

// ── TabBar (compact underline, mirrors _CompactTabBar) ──────────────────────

class _DemosTabBar extends StatelessWidget {
  const _DemosTabBar({
    required this.controller,
    required this.todayCount,
    required this.upcomingCount,
    required this.historyCount,
  });

  final TabController controller;
  final int? todayCount;
  final int? upcomingCount;
  final int? historyCount;

  String _label(String base, int? n) =>
      (n == null) ? base : '$base ($n)';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: AppColors.purple,
        unselectedLabelColor:
            theme.colorScheme.onSurface.withValues(alpha: 0.55),
        indicatorColor: AppColors.purple,
        indicatorSize: TabBarIndicatorSize.label,
        indicatorWeight: 2,
        dividerColor:
            theme.colorScheme.outline.withValues(alpha: 0.15),
        dividerHeight: 1,
        padding: EdgeInsets.zero,
        labelPadding: const EdgeInsets.symmetric(horizontal: 14),
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        tabs: [
          Tab(height: 38, text: _label('Astăzi', todayCount)),
          Tab(height: 38, text: _label('Următoare', upcomingCount)),
          Tab(height: 38, text: _label('Istoric', historyCount)),
        ],
      ),
    );
  }
}

// ── Wide table header (parity with ChildrenTableHeader) ─────────────────────

class _DemosTableHeader extends StatelessWidget {
  const _DemosTableHeader();

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: Theme.of(context).colorScheme.outline,
      letterSpacing: 0.5,
    );
    // Column flex values must stay in sync with [_WideRow] below.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          const SizedBox(width: 48),
          Expanded(flex: 4, child: Text('COPIL · PĂRINTE', style: style)),
          Expanded(flex: 3, child: Text('ATELIER', style: style)),
          Expanded(flex: 3, child: Text('DATA · ORA', style: style)),
          Expanded(flex: 2, child: Text('TRAINER', style: style)),
          SizedBox(width: 90, child: Text('STATUS', style: style)),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

// ── Entry (dispatches wide/narrow) ──────────────────────────────────────────

class _DemoEntry extends ConsumerStatefulWidget {
  const _DemoEntry({
    required this.demo,
    required this.isWide,
    required this.isAdmin,
    required this.tab,
  });
  final DemoWorkshop demo;
  final bool isWide;
  final bool isAdmin;
  final _DemoTab tab;

  @override
  ConsumerState<_DemoEntry> createState() => _DemoEntryState();
}

class _DemoEntryState extends ConsumerState<_DemoEntry> {
  bool _busy = false;

  Future<void> _setStatus(String status) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(demoWorkshopsRepositoryProvider)
          .updateStatus(widget.demo.id, status);
      ref.invalidate(demosForDayProvider);
      ref.invalidate(upcomingDemosProvider);
      ref.invalidate(historyDemosProvider);
      ref.invalidate(todayDemoWorkshopsProvider);
      ref.invalidate(demoWorkshopByIdProvider(widget.demo.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Eroare: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _convert() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await runConvertDemoFlow(
          context: context, ref: ref, demo: widget.demo);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reschedule() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await showRescheduleDemoDialog(
          context: context, ref: ref, original: widget.demo);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openChild() {
    final id = widget.demo.convertedChildId;
    if (id != null) context.push('/children/$id');
  }

  void _openDetails() {
    context.push('/demo-workshops/${widget.demo.id}');
  }

  @override
  Widget build(BuildContext context) {
    final kind = _demoKind(widget.demo);
    final actions = _DemoActions(
      busy: _busy,
      isAdmin: widget.isAdmin,
      kind: kind,
      tab: widget.tab,
      status: widget.demo.status,
      hasChild: widget.demo.convertedChildId != null,
      onPresent: () => _setStatus('completed'),
      onAbsent: () => _setStatus('no_show'),
      onCancel: () => _setStatus('cancelled'),
      onConvert: _convert,
      onReschedule: _reschedule,
      onOpenChild: _openChild,
    );

    if (widget.isWide) {
      return _WideRow(
        demo: widget.demo,
        kind: kind,
        actions: actions,
        onTap: widget.demo.isConverted ? _openChild : _openDetails,
      );
    }
    return _NarrowCard(
      demo: widget.demo,
      kind: kind,
      actions: actions,
      onTap: widget.demo.isConverted ? _openChild : _openDetails,
    );
  }
}

// ── Wide row ────────────────────────────────────────────────────────────────

class _WideRow extends StatelessWidget {
  const _WideRow({
    required this.demo,
    required this.kind,
    required this.actions,
    required this.onTap,
  });
  final DemoWorkshop demo;
  final _DemoKind kind;
  final _DemoActions actions;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (statusLabel, statusColor) = _statusChip(kind, demo.status);
    final parentLine = _parentLine(demo);
    final atelier = _ateliereLabel(demo);
    final dateTime = _dateTimeLabel(demo);
    final trainer = demo.trainerName ?? '—';

    return InkWell(
      onTap: onTap,
      // Discreet web/desktop hover tint. Same visual weight as the
      // Children list hover state (comes from the Material theme).
      hoverColor:
          theme.colorScheme.outline.withValues(alpha: 0.05),
      mouseCursor: SystemMouseCursors.click,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ChildAvatar(name: demo.childFullName, size: 36),
            const SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    demo.childFullName,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (parentLine != null)
                    Text(
                      parentLine,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                atelier,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w500),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                dateTime,
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                trainer,
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: 90,
              child: Align(
                alignment: Alignment.centerLeft,
                child: StatusPill(label: statusLabel, color: statusColor),
              ),
            ),
            // Trailing action slot — intrinsic width so today's
            // scheduled rows (Prezent + Absent + ⋯) have room, while
            // menu-only rows stay compact and align with the header's
            // trailing spacer. The GestureDetector swallows taps on
            // the padding around the buttons so a click near (but not
            // on) an action never bubbles up to the row's InkWell.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44),
                child: actions,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Narrow card ─────────────────────────────────────────────────────────────

class _NarrowCard extends StatelessWidget {
  const _NarrowCard({
    required this.demo,
    required this.kind,
    required this.actions,
    required this.onTap,
  });
  final DemoWorkshop demo;
  final _DemoKind kind;
  final _DemoActions actions;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (statusLabel, statusColor) = _statusChip(kind, demo.status);
    final parentLine = _parentLine(demo);
    final atelier = _ateliereLabel(demo);
    final dateTime = _dateTimeLabel(demo);
    final trainer = demo.trainerName;

    final metaStyle = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.outline);

    return InkWell(
      onTap: onTap,
      hoverColor:
          theme.colorScheme.outline.withValues(alpha: 0.05),
      mouseCursor: SystemMouseCursors.click,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ChildAvatar(name: demo.childFullName, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    demo.childFullName,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                StatusPill(label: statusLabel, color: statusColor),
              ],
            ),
            const SizedBox(height: 8),
            Text(atelier, style: metaStyle),
            Text(dateTime, style: metaStyle),
            if (parentLine != null) Text(parentLine, style: metaStyle),
            if (trainer != null && trainer.isNotEmpty)
              Text('Trainer: $trainer', style: metaStyle),
            const SizedBox(height: 8),
            // Same gesture isolation as the desktop row — the empty
            // space between the actions and the card edge is
            // absorbed here so a tap never leaks to the card's
            // InkWell and opens the details page unintentionally.
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: actions,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Actions (inline Present/Absent on today, menu for everything else) ──────

class _DemoActions extends StatelessWidget {
  const _DemoActions({
    required this.busy,
    required this.isAdmin,
    required this.kind,
    required this.tab,
    required this.status,
    required this.hasChild,
    required this.onPresent,
    required this.onAbsent,
    required this.onCancel,
    required this.onConvert,
    required this.onReschedule,
    required this.onOpenChild,
  });

  final bool busy;
  final bool isAdmin;
  final _DemoKind kind;
  final _DemoTab tab;
  final String status;
  final bool hasChild;
  final VoidCallback onPresent;
  final VoidCallback onAbsent;
  final VoidCallback onCancel;
  final VoidCallback onConvert;
  final VoidCallback onReschedule;
  final VoidCallback onOpenChild;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return const SizedBox(
        width: 32,
        height: 32,
        child: Center(
          child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    // Converted demos — menu-only with "Vezi copil" (no mutation).
    if (status == 'converted') {
      return _DemoActionsMenu(
        tooltip: 'Acțiuni',
        items: [
          if (hasChild)
            _ActionItem(
              value: 'child',
              icon: Icons.person_search_outlined,
              label: 'Vezi copil',
              color: AppColors.purple,
              onTap: onOpenChild,
            ),
        ],
      );
    }

    if (!isAdmin) {
      // Trainer sees the row but has no mutation actions — hide the
      // menu to avoid a dead affordance (RLS also enforces this).
      return const SizedBox(width: 32, height: 32);
    }

    // Today + unmarked scheduled: inline Prezent/Absent + menu with
    // the rest. Everything else collapses into the menu.
    final menuItems = <_ActionItem>[
      if (!(tab == _DemoTab.today && status == 'scheduled')) ...[
        _ActionItem(
          value: 'present',
          icon: Icons.check_rounded,
          label: 'Marchează prezent',
          color: AppColors.success,
          onTap: onPresent,
        ),
        _ActionItem(
          value: 'absent',
          icon: Icons.close_rounded,
          label: 'Marchează absent',
          color: AppColors.warning,
          onTap: onAbsent,
        ),
      ],
      _ActionItem(
        value: 'convert',
        icon: Icons.how_to_reg_rounded,
        label: 'Înscrie definitiv',
        color: AppColors.purple,
        onTap: onConvert,
      ),
      _ActionItem(
        value: 'reschedule',
        icon: Icons.event_repeat_outlined,
        label: 'Reprogramează',
        color: AppColors.info,
        onTap: onReschedule,
      ),
      if (status == 'scheduled')
        _ActionItem(
          value: 'cancel',
          icon: Icons.block_outlined,
          label: 'Anulează demo',
          color: AppColors.error,
          onTap: onCancel,
          isDivider: true,
        ),
    ];

    final menu = _DemoActionsMenu(tooltip: 'Acțiuni', items: menuItems);

    if (tab == _DemoTab.today && status == 'scheduled') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _InlineActionButton(
            icon: Icons.check_rounded,
            color: AppColors.success,
            tooltip: 'Marchează prezent',
            onTap: onPresent,
          ),
          const SizedBox(width: 6),
          _InlineActionButton(
            icon: Icons.close_rounded,
            color: AppColors.warning,
            tooltip: 'Marchează absent',
            onTap: onAbsent,
          ),
          const SizedBox(width: 6),
          menu,
        ],
      );
    }

    return menu;
  }
}

class _ActionItem {
  const _ActionItem({
    required this.value,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isDivider = false,
  });
  final String value;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  /// When true the item renders after a divider — used for the
  /// destructive "Anulează demo" entry so it reads as separate from
  /// the primary actions.
  final bool isDivider;
}

class _DemoActionsMenu extends StatelessWidget {
  const _DemoActionsMenu({
    required this.tooltip,
    required this.items,
  });
  final String tooltip;
  final List<_ActionItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox(width: 32, height: 32);
    }
    return PopupMenuButton<String>(
      tooltip: tooltip,
      offset: const Offset(0, 36),
      onSelected: (v) {
        for (final item in items) {
          if (item.value == v) {
            item.onTap();
            return;
          }
        }
      },
      itemBuilder: (_) {
        final entries = <PopupMenuEntry<String>>[];
        for (final item in items) {
          if (item.isDivider) entries.add(const PopupMenuDivider());
          entries.add(
            PopupMenuItem<String>(
              value: item.value,
              child: ListTile(
                leading: Icon(item.icon, color: item.color),
                title: Text(
                  item.label,
                  style: item.color == AppColors.error
                      ? const TextStyle(color: AppColors.error)
                      : null,
                ),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
          );
        }
        return entries;
      },
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.muted.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.more_horiz_rounded,
              size: 18, color: AppColors.muted),
        ),
      ),
    );
  }
}

class _InlineActionButton extends StatelessWidget {
  const _InlineActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

// ── Empty state ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.tab, required this.hasQuery});
  final _DemoTab tab;
  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (title, subtitle) = switch ((tab, hasQuery)) {
      (_, true) => (
        'Niciun demo nu corespunde căutării',
        'Încearcă alt nume, telefon sau email.',
      ),
      (_DemoTab.today, false) => (
        'Niciun demo astăzi',
        'Programele viitoare apar în "Următoare".',
      ),
      (_DemoTab.upcoming, false) => (
        'Niciun demo programat',
        'Folosește "Programează demo" pentru a adăuga unul.',
      ),
      (_DemoTab.history, false) => (
        'Nu există istoric încă',
        'Demo-urile din trecut apar aici după ce ziua trece.',
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.rocket_launch_outlined,
                size: 40, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(title,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      ),
    );
  }
}

// ── Row semantics (same contract as before — exported for tests) ────────────

enum _DemoKind { future, today, past }

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

_DemoKind _demoKind(DemoWorkshop demo) {
  final today = _today();
  final day = DateTime(
      demo.demoDate.year, demo.demoDate.month, demo.demoDate.day);
  if (day.isAfter(today)) return _DemoKind.future;
  if (day.isAtSameMomentAs(today)) return _DemoKind.today;
  return _DemoKind.past;
}

(String, Color) _statusChip(_DemoKind kind, String status) {
  return switch (status) {
    'converted' => ('Înscris', AppColors.purple),
    'completed' => ('Prezent', AppColors.success),
    'no_show' => ('Absent', AppColors.warning),
    'cancelled' => ('Anulat', AppColors.error),
    'scheduled' => switch (kind) {
        _DemoKind.future => ('Programat', AppColors.info),
        _DemoKind.today => ('Astăzi', AppColors.purple),
        _DemoKind.past => ('Nemarcat', AppColors.muted),
      },
    _ => (status, AppColors.muted),
  };
}

/// Pure helper exported for tests — unchanged signature so the
/// existing `demos_filter_test.dart` suite keeps passing.
@visibleForTesting
(String, _DemoKind) demoRowSemanticsForTest(
    DemoWorkshop demo, DateTime today) {
  final day = DateTime(
      demo.demoDate.year, demo.demoDate.month, demo.demoDate.day);
  final _DemoKind kind;
  if (day.isAfter(today)) {
    kind = _DemoKind.future;
  } else if (day.isAtSameMomentAs(today)) {
    kind = _DemoKind.today;
  } else {
    kind = _DemoKind.past;
  }
  final (label, _) = _statusChip(kind, demo.status);
  return (label, kind);
}

// ── Row formatting helpers ──────────────────────────────────────────────────

String? _parentLine(DemoWorkshop d) {
  final parts = <String>[
    if ((d.parentName ?? '').isNotEmpty) d.parentName!,
    if ((d.parentPhone ?? '').isNotEmpty) d.parentPhone!,
  ];
  if (parts.isEmpty) return null;
  return parts.join(' · ');
}

String _ateliereLabel(DemoWorkshop d) =>
    '${d.workshopTitle} · ${d.workshopType}';

String _dateTimeLabel(DemoWorkshop d) {
  final date =
      '${d.demoDate.day.toString().padLeft(2, '0')}.'
      '${d.demoDate.month.toString().padLeft(2, '0')}.${d.demoDate.year}';
  final start =
      d.startTime.length >= 5 ? d.startTime.substring(0, 5) : d.startTime;
  final end =
      d.endTime.length >= 5 ? d.endTime.substring(0, 5) : d.endTime;
  final timeRange = end.isEmpty ? start : '$start–$end';
  return '$date · $timeRange';
}
