import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A coloured circular avatar showing up to two initials derived from
/// [name]. **Single source of truth for the child-avatar colour** —
/// every screen that renders a child must use [ChildAvatar] (not a
/// custom `CircleAvatar` or hash-coloured circle) so the same child
/// always looks the same.
///
/// Colour rules (per product spec):
///   • Robotică                           → blue   (`AppColors.info`)
///   • Lectură / Tales / Benzi desenate   → yellow (`AppColors.warning`)
///   • Modelare 3D / Imprimare 3D         → green  (`AppColors.success`)
///   • Programare / AI                    → green  (`AppColors.success`)
///   • Desen / Pictură / Culoare          → brand blue (`AppColors.purple`)
///   • Missing or unknown workshop type   → neutral grey (`AppColors.muted`)
///
/// The hash-by-name "random" palette that used to be the fallback was
/// removed — it produced different colours for the same child on
/// different screens (e.g. Workshop Details vs Children list).
class ChildAvatar extends StatelessWidget {
  const ChildAvatar({
    super.key,
    required this.name,
    this.size = 40,
    this.workshopType,
  });

  final String name;
  final double size;

  /// Workshop type string from the DB (e.g. 'Robotică', 'Lectură',
  /// 'Modelare 3D'). When `null` or empty the neutral fallback colour
  /// is used.
  final String? workshopType;

  /// Canonical map from `workshop_type` → child-avatar colour. Used
  /// internally by [ChildAvatar] and exposed `static` so other widgets
  /// that need the matching tint (e.g. a workshop chip next to the
  /// avatar) can reuse it without duplicating the rules.
  static Color colorForWorkshopType(String? type) {
    final t = (type ?? '').toLowerCase();
    if (t.isEmpty) return AppColors.muted;
    if (t.contains('robot')) return AppColors.info;
    if (t.contains('tales') ||
        t.contains('lectur') ||
        t.contains('benzi')) {
      return AppColors.warning;
    }
    if (t.contains('model') || t.contains('imprim') || t.contains('3d')) {
      return AppColors.success;
    }
    if (t.contains('program') ||
        t.contains('ai') ||
        t.contains('inteligen')) {
      return AppColors.success;
    }
    if (t.contains('desen') ||
        t.contains('pictur') ||
        t.contains('culoare')) {
      return AppColors.purple;
    }
    return AppColors.muted;
  }

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    final initials = parts.take(2).map((p) => p[0].toUpperCase()).join();
    final color = colorForWorkshopType(workshopType);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: color,
            fontSize: size * 0.36,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
