import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Shared visual primitives used by every Settings page in the app
/// (staff `/settings` and parent `/parent/profile`). Visual contract
/// is the single source of truth — adjustments to spacing, radii or
/// typography here apply to BOTH surfaces.
///
/// Extracted from the original staff `_SettingsGroup` / `_SettingsTile`
/// / `_ThemeSegmentedButton` / `_LogoutButton` private widgets.

/// Section group with an uppercased icon-prefixed label and a rounded
/// surface container holding [children] separated by hairline dividers.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.children,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Icon(icon, size: 15, color: iconColor),
              const SizedBox(width: 6),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.outline,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: 54,
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One row inside a [SettingsGroup]. Renders the leading icon tile,
/// title, optional subtitle, and either a custom [trailing] widget or
/// a chevron when [showChevron] is true.
///
/// [iconColor] is opt-in. When omitted the leading tile uses the
/// neutral outline-alpha background that the staff Settings page
/// renders. When supplied (e.g. by the parent Information page's
/// Misiunea section), the leading tile uses `iconColor.withValues
/// (alpha: 0.1)` as its background and `iconColor` as the icon
/// foreground — matching the colored-tile language used by
/// [DetailsSectionCard] and `SettingsGroup` header icons.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
    this.showChevron = false,
    this.iconColor,
    this.iconBoxSize = 34,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showChevron;

  /// Optional accent colour for the leading icon tile. When null the
  /// staff-side neutral style is used (background = outline α 0.1,
  /// foreground = onSurface α 0.7). When set the tile renders with
  /// alpha-10 of [iconColor] as the background and the colour itself
  /// as the icon foreground.
  final Color? iconColor;

  /// Edge length (square) of the leading icon tile. Defaults to 34 to
  /// preserve the staff Settings page metrics; the parent
  /// "Informații centru" Misiunea section passes 32 so the row icons
  /// match the `DetailsSectionCard` header icon (also 32 × 32) inside
  /// the same card.
  final double iconBoxSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAccent = iconColor != null;
    final tileBg = hasAccent
        ? iconColor!.withValues(alpha: 0.1)
        : theme.colorScheme.outline.withValues(alpha: 0.1);
    final tileFg = hasAccent
        ? iconColor!
        : theme.colorScheme.onSurface.withValues(alpha: 0.7);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: iconBoxSize,
        height: iconBoxSize,
        decoration: BoxDecoration(
          color: tileBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 17, color: tileFg),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: subtitle.isNotEmpty
          ? Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
            )
          : null,
      trailing: trailing ??
          (showChevron
              ? Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.outline,
                  size: 18,
                )
              : null),
      onTap: onTap,
    );
  }
}

/// Three-segment theme picker used in the "Aspect" group on every
/// Settings page. Pure UI — callers wire [onChanged] to the shared
/// `themeModeProvider`.
class ThemeSegmentedButton extends StatelessWidget {
  const ThemeSegmentedButton({
    super.key,
    required this.themeMode,
    required this.onChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ThemeMode>(
      style: SegmentedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        visualDensity: VisualDensity.compact,
      ),
      segments: const [
        ButtonSegment(
          value: ThemeMode.light,
          icon: Icon(Icons.light_mode_outlined, size: 16),
          tooltip: 'Luminoasă',
        ),
        ButtonSegment(
          value: ThemeMode.system,
          icon: Icon(Icons.brightness_auto_outlined, size: 16),
          tooltip: 'Sistem',
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          icon: Icon(Icons.dark_mode_outlined, size: 16),
          tooltip: 'Întunecată',
        ),
      ],
      selected: {themeMode},
      onSelectionChanged: (sel) => onChanged(sel.first),
      showSelectedIcon: false,
    );
  }
}

/// Bottom-of-page "Deconectare" tile shared by every Settings page.
/// Wraps a `ListTile` in a soft-red outlined container.
class SettingsLogoutTile extends StatelessWidget {
  const SettingsLogoutTile({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: ListTile(
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.logout_rounded,
            size: 17,
            color: AppColors.error,
          ),
        ),
        title: const Text(
          'Deconectare',
          style: TextStyle(
            color: AppColors.error,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
