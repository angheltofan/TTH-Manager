import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/initials_avatar.dart';
import '../../domain/child_model.dart';

/// Width threshold below which the header switches from the original
/// single-row layout (avatar · name · badges · edit) to a vertical
/// "avatar+name" / "badges" stack. Matches the breakpoint used by other
/// responsive surfaces in the app (e.g. `AppTopBar`).
const double _kMobileBreakpoint = 600;

/// Width threshold below which the info row collapses from a 2-column
/// grid to a single column. Keeps long parent names + phone numbers
/// readable on the narrowest devices.
const double _kSingleColumnBreakpoint = 360;

class ChildInfoCard extends StatelessWidget {
  const ChildInfoCard({
    super.key,
    required this.child,
    required this.isAdmin,
    this.workshopType,
  });

  final ChildModel child;
  final bool isAdmin;
  final String? workshopType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = child.isActive == true;
    final isFree = child.paymentType == 'free';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.3)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < _kMobileBreakpoint;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(
                child: child,
                isActive: isActive,
                isFree: isFree,
                isAdmin: isAdmin,
                workshopType: workshopType,
                isMobile: isMobile,
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              _InfoFields(
                child: child,
                maxWidth: constraints.maxWidth,
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Header (avatar + name + badges + edit) ───────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.child,
    required this.isActive,
    required this.isFree,
    required this.isAdmin,
    required this.workshopType,
    required this.isMobile,
  });

  final ChildModel child;
  final bool isActive;
  final bool isFree;
  final bool isAdmin;
  final String? workshopType;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nameStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w800,
      height: 1.2,
    );

    final badges = <Widget>[
      _StatusBadge(isActive: isActive),
      _PaymentTypeBadge(isFree: isFree),
    ];

    final editButton = isAdmin
        ? IconButton(
            icon: const Icon(Icons.edit_outlined,
                color: AppColors.purple, size: 18),
            onPressed: () =>
                GoRouter.of(context).go('/children/${child.id}/edit'),
            tooltip: 'Editează',
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
          )
        : null;

    if (isMobile) {
      // ── Mobile: avatar + full-width name on row 1, badges on row 2 ──
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ChildAvatar(
                  name: child.fullName, size: 48, workshopType: workshopType),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  child.fullName,
                  style: nameStyle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                ),
              ),
              if (editButton != null) ...[
                const SizedBox(width: 4),
                editButton,
              ],
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: badges,
          ),
        ],
      );
    }

    // ── Tablet / desktop: single row, badges Wrap so they fall to a ──
    // ── second line only when the row genuinely runs out of space. ──
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ChildAvatar(
            name: child.fullName, size: 52, workshopType: workshopType),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            child.fullName,
            style: nameStyle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
          ),
        ),
        const SizedBox(width: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.end,
          children: badges,
        ),
        if (editButton != null) ...[
          const SizedBox(width: 4),
          editButton,
        ],
      ],
    );
  }
}

// ── Status badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isActive});
  final bool isActive;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: (isActive ? AppColors.success : AppColors.muted)
              .withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          isActive ? 'Activ' : 'Inactiv',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isActive ? AppColors.success : AppColors.muted,
          ),
        ),
      );
}

// ── Payment-type badge ────────────────────────────────────────────────────────

class _PaymentTypeBadge extends StatelessWidget {
  const _PaymentTypeBadge({required this.isFree});
  final bool isFree;

  @override
  Widget build(BuildContext context) {
    final color = isFree ? AppColors.warning : AppColors.info;
    final icon = isFree ? Icons.school_outlined : Icons.credit_card_outlined;
    final label = isFree ? 'Participare gratuită' : 'Plătitor';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info fields ──────────────────────────────────────────────────────────────

class _InfoFields extends StatelessWidget {
  const _InfoFields({required this.child, required this.maxWidth});

  final ChildModel child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final items = <_InfoItem>[
      if (child.birthDate != null)
        _InfoItem(
          icon: Icons.cake_outlined,
          label: 'Data nașterii',
          value: formatDate(child.birthDate!),
        ),
      if (child.age != null)
        _InfoItem(
          icon: Icons.person_outline_rounded,
          label: 'Vârstă',
          value: '${child.age} ani',
        ),
      _InfoItem(
        icon: Icons.supervisor_account_outlined,
        label: 'Nume părinte',
        value: (child.parentName != null && child.parentName!.isNotEmpty)
            ? child.parentName!
            : '—',
      ),
      if (child.parentPhone != null)
        _InfoItem(
          icon: Icons.phone_outlined,
          label: 'Telefon părinte',
          value: child.parentPhone!,
        ),
      if (child.notes != null && child.notes!.isNotEmpty)
        _InfoItem(
          icon: Icons.notes_outlined,
          label: 'Observații',
          value: child.notes!,
        ),
    ];

    final isMobile = maxWidth < _kMobileBreakpoint;
    final isSingleColumn = maxWidth < _kSingleColumnBreakpoint;

    if (isMobile) {
      // ── Mobile: 2-column responsive grid (1 column < 360 px). ──
      // Sized cells keep the icon+label+value triplet aligned and
      // prevent any single long value from squeezing its neighbours.
      final columns = isSingleColumn ? 1 : 2;
      const hSpacing = 12.0;
      const vSpacing = 10.0;
      final cellWidth =
          (maxWidth - hSpacing * (columns - 1)) / columns;

      // Notes is full-width on mobile because the value can be long;
      // letting it span both columns keeps the grid tidy.
      final gridItems = items.where((i) => i.label != 'Observații').toList();
      final fullWidthItems =
          items.where((i) => i.label == 'Observații').toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: hSpacing,
            runSpacing: vSpacing,
            children: gridItems
                .map((it) => SizedBox(
                      width: cellWidth,
                      child: _InfoChip(item: it),
                    ))
                .toList(),
          ),
          if (fullWidthItems.isNotEmpty) ...[
            const SizedBox(height: vSpacing),
            ...fullWidthItems.map((it) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _InfoChip(item: it),
                )),
          ],
        ],
      );
    }

    // ── Tablet / desktop: keep the original Wrap layout. ──
    return Wrap(
      spacing: 24,
      runSpacing: 10,
      children: items.map((it) => _InfoChip(item: it)).toList(),
    );
  }
}

class _InfoItem {
  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

// ── Info chip: icon + label + value ──────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.item});
  final _InfoItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // `Flexible(fit: FlexFit.loose)` works in BOTH contexts:
    //   • Bounded parent (mobile SizedBox cell)  → Column gets the
    //     remaining bounded width, value text wraps to 2 lines.
    //   • Unbounded parent (desktop Wrap)        → Column takes its
    //     intrinsic single-line width, no wrapping forced.
    // Using `Expanded` here instead would assert under Wrap.
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(item.icon,
            size: 15,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.45)),
        const SizedBox(width: 6),
        Flexible(
          fit: FlexFit.loose,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                item.value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
