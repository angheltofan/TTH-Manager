import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/responsive.dart';
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
    // `animationDuration: Duration.zero` collapses the default
    // `kTabScrollDuration` (300ms) tab-switch animation to zero. The
    // underline still moves — it just snaps to the new tab instead of
    // sliding — so visual tab-state parity is preserved while the
    // content swap feels instantaneous.
    //
    // Why this matters: our listener guards on `!_tabs.indexIsChanging`
    // (to avoid 60fps rebuilds during the animation). With the default
    // duration the guard delayed `setState` by one full animation —
    // the user tapped a tab and had to wait ~300ms before the list
    // rendered the new bucket, even though the data was already
    // cached. With duration zero, `indexIsChanging` goes true→false
    // in the same frame, the listener fires once, the rebuild lands
    // in the next frame.
    _tabs = TabController(
      length: _DemoTab.values.length,
      vsync: this,
      animationDuration: Duration.zero,
    );
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

  /// Stale-while-refresh renderer. Keeps the cached list visible
  /// during an invalidation-triggered refetch so a Prezent/Absent
  /// click doesn't flash the entire list into a spinner. Only a
  /// true first-load (no cached value) shows AppLoading; errors
  /// with no cached value show AppError.
  Widget _buildListSliver({
    required AsyncValue<List<DemoWorkshop>> async,
    required double horizontalPad,
    required bool isWide,
    required bool isAdmin,
    required ThemeData theme,
  }) {
    final cached = async.valueOrNull;
    if (cached == null) {
      if (async.hasError) {
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AppError(message: async.error.toString()),
          ),
        );
      }
      return const SliverToBoxAdapter(
        child: SizedBox(height: 120, child: AppLoading()),
      );
    }
    final filtered = _applySearch(cached, _search);
    if (filtered.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding:
              EdgeInsets.fromLTRB(horizontalPad, 8, horizontalPad, 32),
          child: _EmptyState(
              tab: _currentTab, hasQuery: _search.isNotEmpty),
        ),
      );
    }
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(horizontalPad, 8, horizontalPad, 32),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          if (isWide) ...[
            const _DemosTableHeader(),
            Divider(
              height: 1,
              color: theme.colorScheme.outline.withValues(alpha: 0.25),
            ),
          ],
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: theme.colorScheme.outline.withValues(alpha: 0.18),
            ),
            // Stable per-demo key so Flutter can diff the list in
            // place rather than rebuilding every row when a single
            // status flips.
            itemBuilder: (_, i) => _DemoEntry(
              key: ValueKey(filtered[i].id),
              demo: filtered[i],
              isWide: isWide,
              isAdmin: isAdmin,
              tab: _currentTab,
            ),
          ),
        ]),
      ),
    );
  }

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
          // 16-px gutter on phones (matches Afterschool), 24-px
          // gutter on tablet/desktop (matches Copii).
          final horizontalPad = context.isMobile ? 16.0 : 24.0;
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                    horizontalPad,
                    context.isMobile ? 20 : 24,
                    horizontalPad,
                    0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _DemosHeader(isAdmin: isAdmin),
                    SizedBox(height: context.isMobile ? 14 : 16),
                    SizedBox(
                      width: isWide ? 320 : double.infinity,
                      child: AppSearchField(
                        hint: 'Caută copil, părinte sau telefon...',
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() => _search = v),
                      ),
                    ),
                    SizedBox(height: context.isMobile ? 10 : 16),
                    _DemosTabBar(
                      controller: _tabs,
                      todayCount: todayAsync.valueOrNull?.length,
                      upcomingCount: upcomingAsync.valueOrNull?.length,
                      historyCount: historyAsync.valueOrNull?.length,
                    ),
                  ]),
                ),
              ),
              // Stale-while-refresh: render the cached list even
              // while an invalidation-triggered refetch is in flight,
              // so the user never sees the list flash to a spinner
              // after a mutation. True-first-load (no cached value
              // yet) still shows AppLoading. Errors with no cached
              // value show AppError.
              _buildListSliver(
                async: currentAsync,
                horizontalPad: horizontalPad,
                isWide: isWide,
                isAdmin: isAdmin,
                theme: theme,
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
    // Narrow (< `kMobileBreakpoint`): stack title above the CTA so
    // "Demo-uri" never wraps and the subtitle gets the full width.
    // Wide: current approved desktop layout — icon + title on the
    // left, CTA on the right (same shape as [ChildrenPageHeader]).
    final isMobile = context.isMobile;

    final iconBadge = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.purple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.rocket_launch_outlined,
          color: AppColors.purple, size: 22),
    );

    final titleColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Demo-uri',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          'Gestionează demo-urile și urmărește evoluția lor.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    final action = isAdmin
        ? AppPrimaryButton(
            label: 'Programează demo',
            icon: Icons.add_rounded,
            onPressed: () => context.go('/demo-workshops/new'),
          )
        : null;

    if (isMobile) {
      // Row 1 — icon + title column (full width minus icon).
      // Row 2 — natural-width CTA aligned left, matches the Afterschool
      // mobile header pattern so Demo-uri uses the same visual rhythm.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              iconBadge,
              const SizedBox(width: 12),
              Expanded(child: titleColumn),
            ],
          ),
          if (action != null) ...[
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerLeft, child: action),
          ],
        ],
      );
    }

    // Desktop/tablet — unchanged from the approved layout.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        iconBadge,
        const SizedBox(width: 14),
        Expanded(child: titleColumn),
        ?action,
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
    // Trainer column removed — the released space goes mostly to
    // DATA · ORA (which now carries the weekday prefix) and secondarily
    // to COPIL · PĂRINTE.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          const SizedBox(width: 48),
          Expanded(flex: 4, child: Text('COPIL · PĂRINTE', style: style)),
          Expanded(flex: 3, child: Text('ATELIER', style: style)),
          Expanded(flex: 4, child: Text('DATA · ORA', style: style)),
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
    super.key,
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
      // Scoped invalidation — a status change doesn't move the demo
      // between tabs (date unchanged), so only the demo's own bucket
      // needs to refetch. Was 5 providers; now 2 (bucket + by-id).
      // Realtime still fans out to other tabs/devices via
      // `rt:demo_workshops`.
      invalidateDemoBucketForDate(ref, widget.demo.demoDate);
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
    // Pass the demo as `extra` so the details page can paint its
    // info card immediately on first frame, instead of showing a
    // spinner while the by-id provider refetches the same row.
    context.push('/demo-workshops/${widget.demo.id}', extra: widget.demo);
  }

  @override
  Widget build(BuildContext context) {
    final kind = _demoKind(widget.demo);

    if (widget.isWide) {
      // Desktop keeps the current approved behaviour: inline
      // Prezent/Absent chips next to the ⋯ menu for Astăzi + scheduled.
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
      return _WideRow(
        demo: widget.demo,
        kind: kind,
        actions: actions,
        onTap: widget.demo.isConverted ? _openChild : _openDetails,
      );
    }

    // Mobile — the ⋯ sits inline on the trainer line (compact,
    // bottom-right). Prezent/Absent live as menu items AND, for the
    // Astăzi + scheduled case, as a thin second-row of inline chips
    // below the card body so operational marking stays one-tap.
    final menuActions = _DemoActions(
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
      showInline: false,
    );
    final showInlineRow = widget.isAdmin &&
        !_busy &&
        widget.tab == _DemoTab.today &&
        widget.demo.status == 'scheduled';
    return _NarrowCard(
      demo: widget.demo,
      kind: kind,
      menuActions: menuActions,
      showInlineTodayRow: showInlineRow,
      onPresent: () => _setStatus('completed'),
      onAbsent: () => _setStatus('no_show'),
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
            // workshopType drives the avatar tint — same convention
            // as the Children list, so a Robotică demo lead reads as
            // the same blue family as the enrolled Robotică roster.
            ChildAvatar(
              name: demo.childFullName,
              size: 36,
              workshopType: demo.workshopType,
            ),
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
              flex: 4,
              child: Text(
                dateTime,
                style: theme.textTheme.bodySmall,
                maxLines: 2,
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
    required this.menuActions,
    required this.showInlineTodayRow,
    required this.onPresent,
    required this.onAbsent,
    required this.onTap,
  });
  final DemoWorkshop demo;
  final _DemoKind kind;

  /// Compact ⋯ menu widget — built with `showInline: false` so
  /// Prezent/Absent are folded into it. Sits on the trailing edge of
  /// the trainer line, no isolated action row.
  final Widget menuActions;

  /// True for Astăzi + scheduled rows — adds a thin, left-aligned
  /// Prezent/Absent chip row below the card body so operational
  /// marking stays one-tap on phone.
  final bool showInlineTodayRow;

  final VoidCallback onPresent;
  final VoidCallback onAbsent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (statusLabel, statusColor) = _statusChip(kind, demo.status);
    final parentLine = _parentLine(demo);
    final atelier = _ateliereLabel(demo);
    final dateTime = _dateTimeLabel(demo);

    final metaStyle = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.outline);

    // Gesture-isolation wrapper for anything interactive inside the
    // card. HitTestBehavior.opaque swallows taps on the surrounding
    // padding so a near-miss on an action never leaks to the card's
    // InkWell and opens the details page by accident.
    Widget tapGuard(Widget child) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: child,
        );

    return InkWell(
      onTap: onTap,
      hoverColor:
          theme.colorScheme.outline.withValues(alpha: 0.05),
      mouseCursor: SystemMouseCursors.click,
      child: Padding(
        // Reduced from 14 → h:14 / v:10 so more demos fit per screen.
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ChildAvatar(
              name: demo.childFullName,
              size: 36,
              workshopType: demo.workshopType,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Line 1 — name (expanded) + status pill. The pill
                  // never overlaps the name because the Expanded
                  // absorbs long names into an ellipsis.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          demo.childFullName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusPill(label: statusLabel, color: statusColor),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(atelier,
                      style: metaStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(dateTime,
                      style: metaStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  // Parent · phone line is also where the ⋯ menu sits
                  // on mobile — no separate "Trainer: ..." line and
                  // no empty action block below. Keeps the card tight.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          parentLine ?? '',
                          style: metaStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      tapGuard(menuActions),
                    ],
                  ),
                  // Thin second-row of Prezent/Absent chips — only for
                  // Astăzi + scheduled, since those are the frequent
                  // operational actions a trainer touches multiple
                  // times a day.
                  if (showInlineTodayRow) ...[
                    const SizedBox(height: 6),
                    tapGuard(
                      Row(
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
                        ],
                      ),
                    ),
                  ],
                ],
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
    this.showInline = true,
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

  /// When true (desktop default) the "Astăzi + scheduled" case renders
  /// Prezent/Absent as inline chips next to the ⋯ menu. When false
  /// (mobile), Prezent/Absent are always folded into the menu so the
  /// trailing slot is just the 32×32 ⋯ — the caller renders a
  /// separate thin inline-action row below the card body if needed.
  final bool showInline;

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

    final splitInline =
        showInline && tab == _DemoTab.today && status == 'scheduled';

    // Menu items. When inline Prezent/Absent chips are rendered next
    // to the menu, drop them from the menu; otherwise fold them in so
    // mobile users still have one-tap access through ⋯.
    final menuItems = <_ActionItem>[
      if (!splitInline) ...[
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

    if (splitInline) {
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
  // Example: "Miercuri, 30.09.2026 · 17:00–18:30".
  // Weekday is derived from `demo_date` client-side via the shared
  // formatter — no new DB column.
  final date = formatDateWithWeekday(d.demoDate);
  final start =
      d.startTime.length >= 5 ? d.startTime.substring(0, 5) : d.startTime;
  final end =
      d.endTime.length >= 5 ? d.endTime.substring(0, 5) : d.endTime;
  final timeRange = end.isEmpty ? start : '$start–$end';
  return '$date · $timeRange';
}
