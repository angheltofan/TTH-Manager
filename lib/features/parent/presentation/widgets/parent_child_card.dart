import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/payment_labels.dart';
import '../../../../core/utils/workshop_type_style.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../../children/presentation/widgets/details_section_card.dart';
import '../../domain/parent_dashboard.dart';

/// One card per linked child on the parent dashboard.
///
/// Composes only existing primitives from the staff/admin design:
///   • [DetailsSectionCard] — same shell as the staff Child Details
///     page.
///   • [StatusPill]         — the shared canonical pill (same recipe
///     as `AttendanceStatusBadge` / `PaymentStatusBadge`).
///   • Canonical payment vocabulary via `resolvePaymentLabel`.
///
/// Visual rhythm follows the staff dashboard's lighter cadence: the
/// card has **only one ≥ w700 line in the body** (the workshop title
/// anchor). The three previous inline section headers ("Atelier activ",
/// "Progres ciclu prezențe", "Status plată") were dropped — the
/// workshop title, the progress bar, and the status pill are
/// self-describing visual anchors, so the headers were competing
/// emphasis layers, not navigational cues.
class ParentChildCard extends StatelessWidget {
  const ParentChildCard({super.key, required this.child});
  final ParentDashboardChild child;

  @override
  Widget build(BuildContext context) {
    // Resolve the workshop's icon + accent via the canonical
    // `workshopTypeStyle` helper — same mapping the staff
    // `DashboardWorkshopItem` ("Program săptămâna aceasta" / "Toate
    // atelierele") uses. Only the workshop logo and the progress bar
    // pick up this colour; the workshop title text stays at the default
    // onSurface colour just like the staff workshop cards.
    final (workshopIcon, workshopColor) =
        workshopTypeStyle(child.primaryWorkshop?.workshopType ?? '');

    return DetailsSectionCard(
      title: child.fullName.isEmpty ? '(fără nume)' : child.fullName,
      iconData: Icons.person_outline_rounded,
      // The card's leading child-identity tile stays on brand purple —
      // only the workshop logo inside the body is differentiated by
      // workshop type.
      iconColor: AppColors.purple,
      trailing: child.isPrimary
          ? const StatusPill(
              label: 'Primar',
              color: AppColors.purple,
              hasBorder: false,
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WorkshopBlock(
            child: child,
            workshopIcon: workshopIcon,
            workshopColor: workshopColor,
          ),
          const SizedBox(height: 14),
          _CycleProgressBlock(
            present: child.currentCyclePresent,
            target: child.currentCycleTarget,
            showCountdown: _shouldShowCycleCountdown(child),
            accent: workshopColor,
          ),
          const SizedBox(height: 14),
          _PaymentBlock(child: child),
        ],
      ),
    );
  }

  /// Countdown is informational ("X ședințe până la plată") and only
  /// makes sense while the cycle is still open AND there's no
  /// confirmed/advance payment. Suppressed otherwise so the card
  /// never shows two competing remaining-sessions strings.
  static bool _shouldShowCycleCountdown(ParentDashboardChild child) {
    if (child.currentCyclePresent >= child.currentCycleTarget) return false;
    final status = child.paymentStatus;
    if (status == 'paid' || status == 'paid_advance') return false;
    if (status == 'due' || status == 'overdue') return false;
    return true;
  }
}

// ── Workshop block ─────────────────────────────────────────────────────────
//
// No inline header — the workshop title at bodyLarge w700 purple is
// the section anchor. Meta rows below are bodySmall outline (matches
// the staff `DashboardWorkshopItem` meta line recipe).

class _WorkshopBlock extends StatelessWidget {
  const _WorkshopBlock({
    required this.child,
    required this.workshopIcon,
    required this.workshopColor,
  });

  final ParentDashboardChild child;

  /// Icon for the workshop's type, resolved via `workshopTypeStyle`.
  /// Painted inside the 38 × 38 leading tile — same recipe as the staff
  /// `DashboardWorkshopItem`.
  final IconData workshopIcon;

  /// Accent colour for the leading tile (α 0.1 fill + colored icon).
  /// The workshop title text itself stays at the default `onSurface`
  /// colour so it matches the staff workshop cards.
  final Color workshopColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final workshop = child.primaryWorkshop;
    final extra = child.additionalWorkshopCount;
    if (workshop == null) {
      final hasEnrollment = child.activeWorkshopCount > 0;
      final msg = hasEnrollment
          ? 'Atelier înscris — programarea va apărea aici.'
          : 'Niciun atelier activ.';
      return Text(
        msg,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.outline),
      );
    }
    final start = workshop.startTime != null
        ? formatTimeString(workshop.startTime!)
        : '';
    final end = workshop.endTime != null
        ? formatTimeString(workshop.endTime!)
        : '';
    final time = start.isEmpty ? '' : (end.isEmpty ? start : '$start – $end');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Workshop logo — exactly the same 38 × 38 tile + 19-px icon
        // recipe staff `DashboardWorkshopItem` uses, so a Robotică row
        // looks identical here and in "Program săptămâna aceasta".
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: workshopColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(workshopIcon, color: workshopColor, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                workshop.displayLabel(),
                // Default text colour (matches staff workshop title);
                // colour differentiation is carried only by the logo.
                style: theme.textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 14,
                runSpacing: 4,
                children: [
                  if (workshop.dayOfWeek != null &&
                      workshop.dayOfWeek!.isNotEmpty)
                    _Meta(Icons.calendar_today_outlined, workshop.dayOfWeek!),
                  if (time.isNotEmpty) _Meta(Icons.schedule_outlined, time),
                  if (workshop.trainerName != null &&
                      workshop.trainerName!.isNotEmpty)
                    _Meta(Icons.person_outline_rounded,
                        'Trainer: ${workshop.trainerName!}'),
                  const _Meta(Icons.place_outlined, 'Tales & Tech HUB'),
                ],
              ),
              if (extra > 0) ...[
                const SizedBox(height: 6),
                Text(
                  '+ încă $extra ${extra == 1 ? "atelier" : "ateliere"} '
                  'activ${extra == 1 ? "" : "e"}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.label);
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

// ── Cycle-progress block ───────────────────────────────────────────────────
//
// No inline header — a small caption "Progres ciclu" + "X / Y ședințe"
// on either side of the row carries the same information at outline
// w500, then the bar is the visual anchor. The optional helper line
// (countdown) sits below.

class _CycleProgressBlock extends StatelessWidget {
  const _CycleProgressBlock({
    required this.present,
    required this.target,
    required this.showCountdown,
    required this.accent,
  });
  final int present;
  final int target;
  final bool showCountdown;

  /// Accent colour resolved from the workshop type via the shared
  /// `workshopTypeStyle` helper. The progress bar follows the workshop
  /// accent because the cycle progress is per-workshop.
  final Color accent;

  String? _helper() {
    if (present <= 0) return 'Ciclul nu a început';
    if (present >= target) return 'Ciclu complet';
    if (!showCountdown) return null;
    final remaining = target - present;
    return 'Mai sunt $remaining '
        '${remaining == 1 ? "ședință" : "ședințe"} până la plată';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = target <= 0 ? 0.0 : (present / target).clamp(0.0, 1.0);
    final helper = _helper();
    final captionStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.outline,
      fontWeight: FontWeight.w500,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('Progres ciclu', style: captionStyle)),
            Text('$present / $target ședințe', style: captionStyle),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 6,
            backgroundColor:
                theme.colorScheme.outline.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(accent),
          ),
        ),
        if (helper != null) ...[
          const SizedBox(height: 4),
          Text(
            helper,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ],
    );
  }
}

// ── Payment block ──────────────────────────────────────────────────────────
//
// No inline header — the colored StatusPill IS the section anchor. The
// canonical `resolvePaymentLabel` helper resolves status + method to
// the shared vocabulary ("Plată confirmată POS", "Restant", etc.).
// Falls back to a single outline line when no payment cycle exists.

class _PaymentBlock extends StatelessWidget {
  const _PaymentBlock({required this.child});
  final ParentDashboardChild child;

  String? _helper() {
    switch (child.paymentStatus) {
      case 'paid':
      case 'paid_advance':
        final paidAt = child.paymentPaidAt;
        return paidAt != null ? 'Confirmată pe ${formatDate(paidAt)}.' : null;
      case 'overdue':
        return 'Plata pentru ciclul curent este restantă.';
      case 'due':
        return 'Plata pentru ciclul curent trebuie confirmată.';
      case 'cancelled':
        return null;
      default:
        return 'Nu există ciclu de plată înregistrat.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pill = resolvePaymentLabel(
      status: child.paymentStatus,
      paymentMethod: child.paymentMethod,
    );
    final helper = _helper();

    if (pill == null) {
      if (helper == null) return const SizedBox.shrink();
      return Text(
        helper,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.outline),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatusPill(label: pill.text, color: pill.color),
        if (helper != null) ...[
          const SizedBox(height: 6),
          Text(
            helper,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ],
    );
  }
}
