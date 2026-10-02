import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../../../core/widgets/loading_state.dart';
import '../../auth/providers/auth_providers.dart';
import '../domain/demo_workshop.dart';
import '../providers/demo_workshops_providers.dart';
import 'widgets/demo_convert_flow.dart';
import 'widgets/reschedule_demo_dialog.dart';

/// Demo-uri — first-class management surface for lead demos.
///
///   • Three tabs: Astăzi / Următoare / Istoric. Each is a plain
///     query against the `demo_workshops` table with no implicit
///     status filter, so marked / converted / cancelled demos stay
///     visible with their outcome shown as a pill.
///   • A client-side search filter (child first/last name, parent
///     name, parent phone, parent email) runs over the loaded list
///     for the active tab.
///   • State-aware actions per row — the actions available depend
///     on both the demo's lifecycle status and whether its date is
///     past / today / future. Admin-only; trainers see read-only
///     rows (RLS already enforces the write side).
///
/// Scheduling continues to use the existing [DemoWorkshopFormPage]
/// at `/demo-workshops/new` so both the Dashboard "+ Demo" shortcut
/// and this page's "+ Programează demo" open the same form.
class DemosPage extends ConsumerStatefulWidget {
  const DemosPage({super.key});

  @override
  ConsumerState<DemosPage> createState() => _DemosPageState();
}

enum _DemoTab { today, upcoming, history }

class _DemosPageState extends ConsumerState<DemosPage> {
  _DemoTab _tab = _DemoTab.today;
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final isAdmin = profile?.isAdmin ?? false;

    final AsyncValue<List<DemoWorkshop>> async = switch (_tab) {
      _DemoTab.today => ref.watch(demosForDayProvider(
          DemosDayKey.fromDate(DateTime.now()),
        )),
      _DemoTab.upcoming => ref.watch(upcomingDemosProvider),
      _DemoTab.history => ref.watch(historyDemosProvider),
    };

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPad = context.isMobile ? 16.0 : 24.0;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _Header(isAdmin: isAdmin)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(horizontalPad, 4, horizontalPad, 8),
                  child: _TabBar(
                    current: _tab,
                    onChanged: (t) => setState(() => _tab = t),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(horizontalPad, 4, horizontalPad, 12),
                  child: _SearchField(
                    controller: _searchCtrl,
                    onChanged: (q) => setState(() => _search = q),
                  ),
                ),
              ),
              async.when(
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
                      child: _EmptyState(tab: _tab, hasQuery: _search.isNotEmpty),
                    );
                  }
                  return SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                        horizontalPad, 4, horizontalPad, 24),
                    sliver: SliverList.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _DemoRow(
                        demo: filtered[i],
                        isAdmin: isAdmin,
                      ),
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

/// Case-insensitive substring match across:
///   - child first/last name (and the combined "first last" form so an
///     admin typing the full name hits a result);
///   - parent name;
///   - parent phone (stripped of common separators so "0740 483 442"
///     matches "0740483442");
///   - parent email.
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

/// Visible for testing.
@visibleForTesting
List<DemoWorkshop> applyDemoSearchForTest(
        List<DemoWorkshop> demos, String query) =>
    _applySearch(demos, query);

// ── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.isAdmin});
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = context.isMobile;
    final horizontalPad = isMobile ? 16.0 : 24.0;

    final iconBadge = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.demoBadge.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.rocket_launch_outlined,
          color: AppColors.demoBadge, size: 22),
    );

    final titleColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Demo-uri',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(
          'Gestionează demo-urile și urmărește evoluția lor.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
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
      return Padding(
        padding: EdgeInsets.fromLTRB(horizontalPad, 20, horizontalPad, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              iconBadge,
              const SizedBox(width: 12),
              Expanded(child: titleColumn),
            ]),
            if (action != null) ...[const SizedBox(height: 12), action],
          ],
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPad, 24, horizontalPad, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          iconBadge,
          const SizedBox(width: 14),
          Expanded(child: titleColumn),
          ?action,
        ],
      ),
    );
  }
}

// ── Tab bar ──────────────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  const _TabBar({required this.current, required this.onChanged});
  final _DemoTab current;
  final ValueChanged<_DemoTab> onChanged;

  static const _labels = {
    _DemoTab.today: 'Astăzi',
    _DemoTab.upcoming: 'Următoare',
    _DemoTab.history: 'Istoric',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(builder: (context, box) {
      // Compact segmented control; falls back to Wrap on very narrow phones.
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: theme.colorScheme.outline.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            for (final t in _DemoTab.values)
              Expanded(
                child: _TabChip(
                  label: _labels[t]!,
                  selected: t == current,
                  onTap: () => onChanged(t),
                ),
              ),
          ],
        ),
      );
    });
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? AppColors.demoBadge : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : theme.colorScheme.outline,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Search field ─────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Caută copil, părinte sau telefon...',
        prefixIcon:
            Icon(Icons.search, color: theme.colorScheme.outline, size: 20),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
        filled: true,
        fillColor: theme.cardTheme.color,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: theme.colorScheme.outline.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.demoBadge, width: 1.5),
        ),
      ),
    );
  }
}

// ── Empty state ──────────────────────────────────────────────────────────────

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
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 36),
      child: Column(
        children: [
          Icon(Icons.rocket_launch_outlined,
              size: 44, color: theme.colorScheme.outline),
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
    );
  }
}

// ── Row ──────────────────────────────────────────────────────────────────────

class _DemoRow extends ConsumerStatefulWidget {
  const _DemoRow({required this.demo, required this.isAdmin});
  final DemoWorkshop demo;
  final bool isAdmin;

  @override
  ConsumerState<_DemoRow> createState() => _DemoRowState();
}

class _DemoRowState extends ConsumerState<_DemoRow> {
  bool _busy = false;

  Future<void> _setStatus(String newStatus) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(demoWorkshopsRepositoryProvider)
          .updateStatus(widget.demo.id, newStatus);
      // Realtime handles other tabs; same-tab needs explicit refresh.
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

  @override
  Widget build(BuildContext context) {
    final demo = widget.demo;
    final theme = Theme.of(context);
    final today = _today();
    final demoDay = DateTime(demo.demoDate.year, demo.demoDate.month, demo.demoDate.day);
    final kind = _demoKind(demo, today, demoDay);

    final statusLabel = _statusLabel(kind, demo.status);
    final statusColor = _statusColor(kind, demo.status);

    final meta = <String>[
      '${demo.workshopTitle} · ${demo.workshopType}',
      '${_fmtDate(demo.demoDate)} · ${_fmtTime(demo.startTime)}'
          '${demo.endTime.isNotEmpty ? '–${_fmtTime(demo.endTime)}' : ''}',
      ?_prefixedOrNull('Trainer: ', demo.trainerName),
      ?_prefixedOrNull('Părinte: ', demo.parentName),
      ?_prefixedOrNull('', demo.parentPhone),
    ];

    void goToDetails() => context.push('/demo-workshops/${demo.id}');
    void goToChild() {
      final id = demo.convertedChildId;
      if (id != null) context.push('/children/$id');
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.25)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: demo.isConverted ? goToChild : goToDetails,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ChildAvatar(name: demo.childFullName, size: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(
                              demo.childFullName,
                              style: theme.textTheme.bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _StatusPill(
                              label: statusLabel, color: statusColor),
                        ]),
                        const SizedBox(height: 4),
                        for (final line in meta)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              line,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (widget.isAdmin) ...[
                const SizedBox(height: 10),
                _ActionsBar(
                  kind: kind,
                  isConverted: demo.isConverted,
                  busy: _busy,
                  onPresent: () => _setStatus('completed'),
                  onAbsent: () => _setStatus('no_show'),
                  onConvert: _convert,
                  onReschedule: _reschedule,
                  onOpenChild: demo.convertedChildId != null ? goToChild : null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Row semantics helpers ────────────────────────────────────────────────────

enum _DemoKind { future, today, past }

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

_DemoKind _demoKind(DemoWorkshop demo, DateTime today, DateTime demoDay) {
  if (demoDay.isAfter(today)) return _DemoKind.future;
  if (demoDay.isAtSameMomentAs(today)) return _DemoKind.today;
  return _DemoKind.past;
}

String _statusLabel(_DemoKind kind, String status) {
  return switch (status) {
    'converted' => 'Înscris',
    'completed' => 'Prezent',
    'no_show' => 'Absent',
    'cancelled' => 'Anulat',
    'scheduled' => switch (kind) {
        _DemoKind.future => 'Programat',
        _DemoKind.today => 'Astăzi',
        _DemoKind.past => 'Nemarcat',
      },
    _ => status,
  };
}

Color _statusColor(_DemoKind kind, String status) {
  return switch (status) {
    'converted' => AppColors.purple,
    'completed' => AppColors.success,
    'no_show' => AppColors.warning,
    'cancelled' => AppColors.error,
    'scheduled' => switch (kind) {
        _DemoKind.future => AppColors.info,
        _DemoKind.today => AppColors.demoBadge,
        _DemoKind.past => AppColors.muted,
      },
    _ => AppColors.muted,
  };
}

/// Pure helper exported for tests.
@visibleForTesting
(String, _DemoKind) demoRowSemanticsForTest(
    DemoWorkshop demo, DateTime today) {
  final day = DateTime(demo.demoDate.year, demo.demoDate.month, demo.demoDate.day);
  final kind = _demoKind(demo, today, day);
  return (_statusLabel(kind, demo.status), kind);
}

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.'
    '${d.month.toString().padLeft(2, '0')}.${d.year}';

String _fmtTime(String hhmm) =>
    hhmm.length >= 5 ? hhmm.substring(0, 5) : hhmm;

/// Returns `prefix + v` when `v` is non-null and non-empty, else `null`
/// so the caller can drop the entry via a null-aware spread.
String? _prefixedOrNull(String prefix, String? v) =>
    (v == null || v.isEmpty) ? null : '$prefix$v';

// ── Status pill ──────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ── Actions bar ──────────────────────────────────────────────────────────────

class _ActionsBar extends StatelessWidget {
  const _ActionsBar({
    required this.kind,
    required this.isConverted,
    required this.busy,
    required this.onPresent,
    required this.onAbsent,
    required this.onConvert,
    required this.onReschedule,
    required this.onOpenChild,
  });

  final _DemoKind kind;
  final bool isConverted;
  final bool busy;
  final VoidCallback onPresent;
  final VoidCallback onAbsent;
  final VoidCallback onConvert;
  final VoidCallback onReschedule;

  /// Supplied when the demo is already linked to a child so the row
  /// has a dedicated "Vezi copil" action instead of surfacing the
  /// (now disabled) convert flow a second time.
  final VoidCallback? onOpenChild;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    // Converted demos: single "Vezi copil" action, no mutation controls.
    if (isConverted) {
      return Align(
        alignment: Alignment.centerLeft,
        child: _MiniBtn(
          icon: Icons.person_search_outlined,
          label: 'Vezi copil',
          color: AppColors.purple,
          onTap: onOpenChild,
        ),
      );
    }

    // State-aware action set. Rules:
    //   future → Reprogramează only (no premature attendance).
    //   today  → Prezent + Absent + Înscrie + Reprogramează.
    //   past   → Admin can still correct attendance (Prezent / Absent),
    //            Înscrie definitiv remains available (late conversion),
    //            Reprogramează remains available (follow-up appointment).
    final actions = <_ActionSpec>[];
    switch (kind) {
      case _DemoKind.future:
        actions.add(_ActionSpec(
          icon: Icons.event_repeat_outlined,
          label: 'Reprogramează',
          color: AppColors.info,
          onTap: onReschedule,
        ));
      case _DemoKind.today:
      case _DemoKind.past:
        actions.addAll([
          _ActionSpec(
              icon: Icons.check_rounded,
              label: 'Prezent',
              color: AppColors.success,
              onTap: onPresent),
          _ActionSpec(
              icon: Icons.close_rounded,
              label: 'Absent',
              color: AppColors.warning,
              onTap: onAbsent),
          _ActionSpec(
              icon: Icons.how_to_reg_rounded,
              label: 'Înscrie definitiv',
              color: AppColors.purple,
              onTap: onConvert),
          _ActionSpec(
              icon: Icons.event_repeat_outlined,
              label: 'Reprogramează',
              color: AppColors.info,
              onTap: onReschedule),
        ]);
    }

    // Wrap handles narrow screens — on phone the four buttons fall onto
    // two rows cleanly instead of overflowing a Row.
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final a in actions)
          _MiniBtn(
            icon: a.icon,
            label: a.label,
            color: a.color,
            onTap: a.onTap,
          ),
      ],
    );
  }
}

class _ActionSpec {
  const _ActionSpec({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

class _MiniBtn extends StatelessWidget {
  const _MiniBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
