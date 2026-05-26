import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/notification_bell.dart';
import '../../auth/providers/auth_providers.dart';
import '../domain/parent_dashboard.dart';
import '../providers/parent_dashboard_providers.dart';
import '../utils/parent_status_labels.dart';
import 'widgets/parent_bottom_nav.dart';
import 'widgets/parent_quick_contact_card.dart';
import 'widgets/parent_section_card.dart';

/// Top-level shell for the parent role. Rendered as a standalone route
/// (`/parent`) outside the staff `ShellRoute`, so parents never see the
/// admin/trainer sidebar, top bar, or bottom navigation.
class ParentShell extends ConsumerWidget {
  const ParentShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final firstName = profile?.firstName ?? '';
    final childrenAsync = ref.watch(parentLinkedChildrenProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          firstName.isEmpty ? 'Tales & Tech Parent' : 'Bună, $firstName',
        ),
        actions: [
          // Same widget as the staff bell; the providers it reads
          // (recentNotifications + unreadCount) are already scoped to
          // recipient_id = auth.uid() via the notifications_select_recipient_self
          // RLS policy added in P2. The dropdown's "Toate notificările"
          // footer targets the parent's own notifications page so the
          // router redirect won't bounce them.
          const AppNotificationBell(
            viewAllRoute: '/parent/notifications',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Deconectează-te',
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      bottomNavigationBar: const ParentBottomNav(currentIndex: 0),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(parentLinkedChildrenProvider);
          await ref.read(parentLinkedChildrenProvider.future);
        },
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: context.mobilePadding,
              child: childrenAsync.when(
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
                  if (kDebugMode) {
                    debugPrint('[Parent/Dashboard] load failed: $e');
                  }
                  return ParentSectionCard(
                    title: 'Eroare',
                    child: Text(
                      'A apărut o eroare. Trage în jos pentru a reîncerca.',
                      style: theme.textTheme.bodySmall,
                    ),
                  );
                },
                data: (children) {
                  if (children.isEmpty) {
                    return ParentSectionCard(
                      title: 'Bine ai venit!',
                      child: Text(
                        'Nu există încă niciun copil asociat contului.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    );
                  }

                  final focal = children.firstWhere(
                    (c) => c.isPrimary,
                    orElse: () => children.first,
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Children
                      for (var i = 0; i < children.length; i++) ...[
                        if (i > 0) SizedBox(height: context.sectionGap),
                        _ChildSummaryCard(child: children[i]),
                      ],
                      SizedBox(height: context.sectionGap),

                      // Next workshop
                      _NextWorkshopSection(childId: focal.id),
                      SizedBox(height: context.sectionGap),

                      // Recent activity
                      _RecentActivitySection(childId: focal.id),
                      SizedBox(height: context.sectionGap),

                      // Quick contact
                      const ParentQuickContactCard(),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Child summary card ────────────────────────────────────────────────────────

class _ChildSummaryCard extends StatelessWidget {
  const _ChildSummaryCard({required this.child});
  final ParentDashboardChild child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final relLabel = (child.relationship ?? '').trim();
    return InkWell(
      onTap: () => context.push('/parent/children/${child.id}'),
      borderRadius: BorderRadius.circular(context.cardRadius),
      child: ParentSectionCard(
        title: child.fullName.isEmpty ? '(fără nume)' : child.fullName,
        icon: Icons.child_care_rounded,
        iconColor: const Color(0xFFEC4899),
        trailing: child.isPrimary
            ? Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Primar',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.purple,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (relLabel.isNotEmpty) ...[
              Text(
                relLabel,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 10),
            ],
            _MetaRow(
              icon: Icons.school_rounded,
              label: '${child.activeWorkshopCount} '
                  '${child.activeWorkshopCount == 1 ? "atelier activ" : "ateliere active"}',
            ),
            const SizedBox(height: 6),
            _MetaRow(
              icon: Icons.checklist_rounded,
              label:
                  'Ciclu curent: ${child.currentCyclePresent}/${child.currentCycleTarget} prezențe',
            ),
            const SizedBox(height: 6),
            _MetaRow(
              icon: Icons.credit_card_rounded,
              label: 'Plată: ${parentPaymentLabel(child.paymentStatus)}',
              labelColor: parentPaymentColor(child.paymentStatus),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Vezi detalii →',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.purple,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Next workshop section ─────────────────────────────────────────────────────

class _NextWorkshopSection extends ConsumerWidget {
  const _NextWorkshopSection({required this.childId});
  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(parentNextWorkshopProvider(childId));
    return ParentSectionCard(
      title: 'Următorul atelier',
      icon: Icons.event_rounded,
      iconColor: const Color(0xFF3B82F6),
      child: async.when(
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
              'Nu există niciun atelier programat.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            );
          }
          final endLabel = workshop.endTime != null
              ? formatTimeString(workshop.endTime!)
              : '';
          final startLabel = workshop.startTime != null
              ? formatTimeString(workshop.startTime!)
              : '';
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
                style: theme.textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              if (workshop.workshopDate != null)
                _MetaRow(
                  icon: Icons.calendar_today_outlined,
                  label:
                      '${workshop.dayOfWeek ?? ""}, ${formatDateLong(workshop.workshopDate!)}'
                          .replaceAll(RegExp(r'^, '), ''),
                ),
              if (timeRange.isNotEmpty) ...[
                const SizedBox(height: 6),
                _MetaRow(icon: Icons.schedule_outlined, label: timeRange),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ── Recent activity section ───────────────────────────────────────────────────

class _RecentActivitySection extends ConsumerWidget {
  const _RecentActivitySection({required this.childId});
  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(parentRecentActivityProvider(childId));
    return ParentSectionCard(
      title: 'Activitate recentă',
      icon: Icons.history_rounded,
      iconColor: const Color(0xFF10B981),
      child: async.when(
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
        data: (activity) {
          if (activity.isEmpty) {
            return Text(
              'Nicio activitate recentă.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (activity.lastAttendance != null) ...[
                _ActivityRow(
                  icon: Icons.event_available_rounded,
                  label: 'Ultima prezență',
                  detail: _attendanceDetail(activity.lastAttendance!),
                ),
                const SizedBox(height: 10),
              ],
              if (activity.lastPayment != null) ...[
                _ActivityRow(
                  icon: Icons.credit_card_rounded,
                  label: 'Status plată',
                  detail: _paymentDetail(activity.lastPayment!),
                ),
                const SizedBox(height: 10),
              ],
              if (activity.lastNotification != null) ...[
                _ActivityRow(
                  icon: Icons.notifications_rounded,
                  label: 'Notificare recentă',
                  detail: _notificationDetail(activity.lastNotification!),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  static String _attendanceDetail(ParentRecentAttendance a) {
    final statusLabel = parentAttendanceLabel(a.status);
    final dateLabel =
        a.workshopDate != null ? formatDate(a.workshopDate!) : '—';
    final title = (a.workshopTitle ?? '').trim();
    return title.isEmpty
        ? '$statusLabel pe $dateLabel'
        : '$statusLabel pe $dateLabel · $title';
  }

  static String _paymentDetail(ParentRecentPayment p) {
    final label = parentPaymentLabel(p.status);
    if (p.status == 'paid' && p.paidAt != null) {
      return '$label · ${formatDate(p.paidAt!)}';
    }
    if (p.periodEnd != null) {
      return '$label · ciclu până la ${formatDate(p.periodEnd!)}';
    }
    return label;
  }

  static String _notificationDetail(ParentRecentNotification n) {
    final date = n.createdAt != null ? formatDate(n.createdAt!) : '';
    return date.isEmpty ? n.title : '${n.title} · $date';
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────────

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.label,
    this.labelColor,
  });

  final IconData icon;
  final String label;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.outline),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: labelColor ?? theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.icon,
    required this.label,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.outline),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(detail, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

