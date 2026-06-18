import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../children/presentation/widgets/details_section_card.dart';
import '../../settings/presentation/widgets/settings_widgets.dart';
import 'widgets/parent_quick_contact_card.dart';

/// Static "Informații centru" page mounted at `/parent/info`.
///
/// Rendered inside the persistent `ParentShell` (mounted by the parent
/// `ShellRoute` in `router.dart`) — owns only its content.
///
/// Composed exclusively from existing shared primitives:
///   • [DetailsSectionCard]       — every section shell
///   • [SettingsTile]             — mission info rows (with colored
///                                  icon tiles)
///   • [ParentQuickContactCard]   — contact section
///   • [AppColors] palette — no raw hex
///
/// Five sections in order: Hero, Workshop categories (2-col grid on
/// tablet/desktop), Mission, Program + Location (side-by-side on wide),
/// Contact CTA.
class ParentAboutPage extends ConsumerWidget {
  const ParentAboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: context.mobilePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PageHeader(theme: theme),
          SizedBox(height: context.sectionGap),
          const _HeroCard(),
          SizedBox(height: context.sectionGap),
          const _WorkshopCategoriesSection(),
          SizedBox(height: context.sectionGap),
          const _MissionCard(),
          SizedBox(height: context.sectionGap),
          const _ProgramAndLocationSection(),
          SizedBox(height: context.sectionGap),
          const ParentQuickContactCard(title: 'Contactează-ne'),
        ],
      ),
    );
  }
}

// ── Page header (title + subtitle, matches staff Settings header) ──────────

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Informații centru',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Centrul educațional unde copiii învață tehnologie, '
          'creativitate și gândire practică.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

// ── Section 1 — Hero / brand card ──────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  static const _highlights = <String>[
    'Grupe mici',
    'Mentori specializați',
    'Învățare practică',
    'Materiale incluse',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Hero card — no DetailsSectionCard header. The body block owns the
    // brand: logo + title + subtitle. This removes the previous 4-anchor
    // stacking (header icon + logo + body title + subtitle) the parity
    // audit flagged.
    return DetailsSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/app_logo.png',
                  width: 56,
                  height: 56,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // `titleMedium w700 letterSpacing: -0.2` — same
                    // recipe the shared SectionCard uses for its
                    // titles.
                    Text(
                      'Tales & Tech HUB',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Centru Educațional',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Tales & Tech HUB este un centru educațional din Suceava '
            'dedicat copiilor între 6 și 14 ani, unde tehnologia, '
            'creativitatea și învățarea practică se întâlnesc.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final label in _highlights) _HighlightChip(label: label),
            ],
          ),
        ],
      ),
    );
  }
}

class _HighlightChip extends StatelessWidget {
  const _HighlightChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.purple.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_rounded, size: 14, color: AppColors.purple),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.purple,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section 2 — Workshop categories ────────────────────────────────────────

class _WorkshopCategoriesSection extends StatelessWidget {
  const _WorkshopCategoriesSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'Atelierele noastre',
            // Same `titleMedium w700 letterSpacing -0.2` recipe the
            // shared `SectionCard.title` uses — keeps inline section
            // headings on the parent surface aligned with the app's
            // shared section-title rhythm.
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ),
        // Explicit 2-col layout. `ResponsiveGrid` could not maintain a
        // strict 2×2 across both tablet (~720 px content) and wide
        // desktop (~1118 px content) — its column count is driven by
        // `minItemWidth`, and the same value cannot satisfy both
        // breakpoints. We pin to 2 columns at ≥ 600 px and a single
        // column below.
        const _WorkshopCategoriesGrid(
          categories: [
            _WorkshopCategoryCard(
              icon: Icons.smart_toy_outlined,
              iconColor: AppColors.info,
              title: 'Robotică',
              description:
                  'Construim roboți, învățăm mecanică, logică și '
                  'programare prin proiecte practice. Învățăm inginerie'
                  'prin asamblare si programare.',
            ),
            _WorkshopCategoryCard(
              icon: Icons.memory_rounded,
              iconColor: AppColors.purple,
              title: 'Programare și Inteligență Artificială',
              description:
                  'Copiii construiesc jocuri, aplicații și descoperă '
                  'lumea programării și a inteligenței artificiale.',
            ),
            _WorkshopCategoryCard(
              icon: Icons.menu_book_rounded,
              iconColor: AppColors.warning,
              title: 'Lectură și Artă Ilustrativă',
              description:
                  'Creăm povești, benzi desenate și proiecte creative '
                  'care combină imaginația cu tehnologia.',
            ),
            _WorkshopCategoryCard(
              icon: Icons.view_in_ar_outlined,
              iconColor: AppColors.success,
              title: 'Modelare și Imprimare 3D',
              description:
                  'Modelăm obiecte digitale și descoperim procesul de '
                  'imprimare 3D prin proiecte reale.',
            ),
          ],
        ),
      ],
    );
  }
}

/// Explicit 2-column grid that switches to a single column below 600 px.
/// Stays 2-column on every tablet/desktop breakpoint (≥ 600 px),
/// regardless of viewport — fixes the strict 2×2 spec that
/// `ResponsiveGrid` could not honour with a single `minItemWidth`.
class _WorkshopCategoriesGrid extends StatelessWidget {
  const _WorkshopCategoriesGrid({required this.categories});

  final List<Widget> categories;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;
        if (!isWide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < categories.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                categories[i],
              ],
            ],
          );
        }
        final rows = <Widget>[];
        for (var i = 0; i < categories.length; i += 2) {
          final left = categories[i];
          final right =
              (i + 1 < categories.length) ? categories[i + 1] : null;
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: left),
                  const SizedBox(width: 12),
                  Expanded(
                    child: right ?? const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              rows[i],
            ],
          ],
        );
      },
    );
  }
}

class _WorkshopCategoryCard extends StatelessWidget {
  const _WorkshopCategoryCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DetailsSectionCard(
      title: title,
      iconData: icon,
      iconColor: iconColor,
      child: Text(
        description,
        style: theme.textTheme.bodyMedium,
      ),
    );
  }
}

// ── Section 3 — Mission ────────────────────────────────────────────────────

class _MissionCard extends StatelessWidget {
  const _MissionCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DetailsSectionCard(
      title: 'Misiunea noastră',
      iconData: Icons.lightbulb_outline_rounded,
      iconColor: AppColors.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ne propunem să dezvoltăm creativitatea, logica, '
            'competențele digitale și încrederea copiilor prin '
            'experiențe educaționale moderne și aplicate.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          // Reuse SettingsTile with colored leading icons (opt-in via
          // `iconColor`) so the rows visually match the staff settings
          // tile style while picking up the dashboard/stat card color
          // language. `iconBoxSize: 32` aligns the leading tile size
          // with the surrounding `DetailsSectionCard` header icon
          // (also 32 × 32) — same icon rhythm inside one card.
          const SettingsTile(
            icon: Icons.groups_outlined,
            iconColor: AppColors.info,
            iconBoxSize: 32,
            title: 'Atenție individuală',
            subtitle: 'Lucrăm în grupe mici (maxim 10 copii).',
          ),
          _RowDivider(theme: theme),
          const SettingsTile(
            icon: Icons.workspace_premium_outlined,
            iconColor: AppColors.purple,
            iconBoxSize: 32,
            title: 'Mentori experimentați',
            subtitle: 'Specialiști IT și pedagogi dedicați.',
          ),
          _RowDivider(theme: theme),
          const SettingsTile(
            icon: Icons.inventory_2_outlined,
            iconColor: AppColors.success,
            iconBoxSize: 32,
            title: 'Totul inclus',
            subtitle:
                'Punem la dispoziție laptopuri, roboți și materiale.',
          ),
        ],
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 54,
      color: theme.colorScheme.outline.withValues(alpha: 0.2),
    );
  }
}

// ── Section 4 — Program & Location ─────────────────────────────────────────

class _ProgramAndLocationSection extends StatelessWidget {
  const _ProgramAndLocationSection();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const program = _ProgramCard();
        const location = _LocationCard();
        final isWide = constraints.maxWidth >= 720;

        if (!isWide) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              program,
              SizedBox(height: 12),
              location,
            ],
          );
        }
        return const IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: program),
              SizedBox(width: 12),
              Expanded(child: location),
            ],
          ),
        );
      },
    );
  }
}

class _ProgramCard extends StatelessWidget {
  const _ProgramCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DetailsSectionCard(
      title: 'Program',
      iconData: Icons.schedule_outlined,
      iconColor: AppColors.info,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ScheduleBlock(
            label: 'Luni – Vineri',
            hours: '10:00 – 19:00',
            theme: theme,
          ),
          const SizedBox(height: 12),
          _ScheduleBlock(
            label: 'Sâmbătă',
            hours: '10:00 – 13:00',
            theme: theme,
          ),
        ],
      ),
    );
  }
}

class _ScheduleBlock extends StatelessWidget {
  const _ScheduleBlock({
    required this.label,
    required this.hours,
    required this.theme,
  });

  final String label;
  final String hours;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          hours,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DetailsSectionCard(
      title: 'Locație',
      iconData: Icons.location_on_outlined,
      iconColor: AppColors.success,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tales & Tech HUB Suceava',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Strada Universității nr. 32',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 2),
          Text(
            'Suceava',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Vizavi de Parcul Universității',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
