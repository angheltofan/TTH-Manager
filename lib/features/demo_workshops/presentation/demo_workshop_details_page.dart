import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../auth/providers/auth_providers.dart';
import '../domain/demo_workshop.dart';
import '../providers/demo_workshops_providers.dart';
import 'widgets/demo_convert_flow.dart';
import 'widgets/reschedule_demo_dialog.dart';

// ── DemoWorkshopDetailsPage ───────────────────────────────────────────────────

class DemoWorkshopDetailsPage extends ConsumerStatefulWidget {
  const DemoWorkshopDetailsPage({
    super.key,
    required this.demoId,
    this.initialDemo,
  });
  final String demoId;

  /// Pre-loaded demo row supplied by the Demo-uri list via GoRouter
  /// `extra`, so the info card paints on first frame instead of
  /// showing a spinner while the by-id provider re-fetches. When
  /// null (deep link, Dashboard shortcut, cold navigation) the page
  /// falls back to the loading state as before.
  final DemoWorkshop? initialDemo;

  @override
  ConsumerState<DemoWorkshopDetailsPage> createState() =>
      _DemoWorkshopDetailsPageState();
}

class _DemoWorkshopDetailsPageState
    extends ConsumerState<DemoWorkshopDetailsPage> {
  bool _busy = false;

  Future<void> _setStatus(String status, String label) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: Text('Confirmi modificarea statusului la "$label"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Anulează')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmă')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(demoWorkshopsRepositoryProvider)
          .updateStatus(widget.demoId, status);
      // Manual invalidations removed: appRealtimeProvider's
      // `rt:demo_workshops` channel already invalidates
      // demoWorkshopByIdProvider, todayDemoWorkshopsProvider and
      // dashboardStatsProvider on the same row change — duplicating
      // them here fired six refetches per status update.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Eroare: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _convert(DemoWorkshop demo) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // Shared flow — single source of truth with the Demo-uri list.
      await runConvertDemoFlow(
          context: context, ref: ref, demo: demo);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reschedule(DemoWorkshop demo) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await showRescheduleDemoDialog(
          context: context, ref: ref, original: demo);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final demoAsync = ref.watch(demoWorkshopByIdProvider(widget.demoId));
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final isAdmin = profile?.isAdmin ?? false;
    final theme = Theme.of(context);

    // Prefer the provider's fresh value, fall back to the extra
    // supplied by the caller so the first frame renders instantly
    // when the user came from the Demo-uri list. Only show the
    // spinner on a true cold load (deep link / Dashboard shortcut
    // with no caller-supplied demo).
    final demo = demoAsync.valueOrNull ?? widget.initialDemo;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/dashboard'),
        ),
        title: const Text('Demo atelier'),
      ),
      body: Builder(builder: (context) {
        if (demo == null) {
          if (demoAsync.hasError) {
            return Center(
                child: AppError(message: demoAsync.error.toString()));
          }
          return const AppLoading();
        }
        return _buildBody(context, demo, isAdmin);
      }),
    );
  }

  Widget _buildBody(BuildContext context, DemoWorkshop demo, bool isAdmin) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DemoInfoCard(demo: demo),
          const SizedBox(height: 20),
          if (isAdmin && demo.isScheduled) ...[
            _AdminActionsCard(
              demo: demo,
              busy: _busy,
              onMarkCompleted: () => _setStatus('completed', 'Finalizat'),
              onMarkNoShow: () => _setStatus('no_show', 'Absent'),
              onCancel: () => _setStatus('cancelled', 'Anulat'),
              onConvert: () => _convert(demo),
              onReschedule: () => _reschedule(demo),
            ),
          ],
          if (!demo.isScheduled) _StatusBanner(status: demo.status),
        ],
      ),
    );
  }
}

// ── Info card ─────────────────────────────────────────────────────────────────

class _DemoInfoCard extends StatelessWidget {
  const _DemoInfoCard({required this.demo});
  final DemoWorkshop demo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget row(IconData icon, String label, String? value) {
      if (value == null || value.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon,
                size: 16, color: theme.colorScheme.outline),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline)),
                  Text(value,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.35)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  demo.childFullName,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              _DemoBadge(),
              const SizedBox(width: 8),
              _StatusChip(status: demo.status),
            ],
          ),
          const SizedBox(height: 14),
          row(Icons.person_outline, 'Nume părinte', demo.parentName),
          row(Icons.phone_outlined, 'Telefon', demo.parentPhone),
          row(Icons.email_outlined, 'Email', demo.parentEmail),
          row(Icons.calendar_today_outlined, 'Dată',
              formatDate(demo.demoDate)),
          row(Icons.access_time_outlined, 'Oră',
              '${formatTimeString(demo.startTime)} – ${formatTimeString(demo.endTime)}'),
          row(Icons.category_outlined, 'Tip atelier', demo.workshopType),
          row(Icons.event_outlined, 'Titlu atelier', demo.workshopTitle),
          row(Icons.person_pin_outlined, 'Trainer', demo.trainerName),
          row(Icons.notes_outlined, 'Note', demo.notes),
        ],
      ),
    );
  }
}

// ── Admin actions card ────────────────────────────────────────────────────────

class _AdminActionsCard extends StatelessWidget {
  const _AdminActionsCard({
    required this.demo,
    required this.busy,
    required this.onMarkCompleted,
    required this.onMarkNoShow,
    required this.onCancel,
    required this.onConvert,
    required this.onReschedule,
  });
  final DemoWorkshop demo;
  final bool busy;
  final VoidCallback onMarkCompleted;
  final VoidCallback onMarkNoShow;
  final VoidCallback onCancel;
  final VoidCallback onConvert;
  final VoidCallback onReschedule;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: onConvert,
          icon: const Icon(Icons.how_to_reg_rounded),
          label: const Text('Înscrie definitiv'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.success,
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onReschedule,
          icon: const Icon(Icons.event_repeat_outlined),
          label: const Text('Reprogramează'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.info,
            minimumSize: const Size.fromHeight(44),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onMarkCompleted,
                child: const Text('Prezent'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: onMarkNoShow,
                child: const Text('Absent'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error),
                child: const Text('Anulează'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Status banner shown when demo is no longer scheduled ─────────────────────

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'completed' => ('Finalizat', AppColors.success),
      'no_show' => ('Absent', AppColors.warning),
      'cancelled' => ('Anulat', AppColors.error),
      'converted' => ('Înscris definitiv', AppColors.purple),
      _ => (status, AppColors.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: color, size: 18),
          const SizedBox(width: 10),
          Text(
            'Status: $label',
            style: TextStyle(
                color: color, fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ── Small badge / chip widgets ────────────────────────────────────────────────

class _DemoBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.demoBadge.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'DEMO',
        style: TextStyle(
          color: AppColors.demoBadge,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'scheduled' => ('Programat', AppColors.info),
      'completed' => ('Finalizat', AppColors.success),
      'no_show' => ('Absent', AppColors.warning),
      'cancelled' => ('Anulat', AppColors.error),
      'converted' => ('Înscris', AppColors.purple),
      _ => (status, AppColors.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// The series picker now lives inside `widgets/demo_convert_flow.dart`
// so the Demo-uri list row and the details page share one source.
