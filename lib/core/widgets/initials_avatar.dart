import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A colored circular avatar showing up to two initials derived from [name].
/// Background color is driven by [workshopType] when provided, otherwise
/// deterministically derived from [name] (same name → same color).
class ChildAvatar extends StatelessWidget {
  const ChildAvatar({
    super.key,
    required this.name,
    this.size = 40,
    this.workshopType,
  });

  final String name;
  final double size;
  /// Workshop type string from DB (e.g. 'Robotică', 'Tales', 'Modelare 3D').
  final String? workshopType;

  static const List<Color> _palette = [
    AppColors.purple,
    Color(0xFF3B82F6),
    AppColors.success,
    AppColors.warning,
    AppColors.error,
    AppColors.teal,
    Color(0xFFF97316),
    Color(0xFF8B5CF6),
  ];

  static Color colorForName(String name) =>
      _palette[name.hashCode.abs() % _palette.length];

  /// Returns a color based on workshop category:
  /// - Robotică / Robotics → blue
  /// - Tales / Lectură / Benzi desenate → yellow/amber
  /// - Modelare 3D / Imprimare 3D → green
  /// - anything else → muted gray
  static Color colorForWorkshopType(String type) {
    final t = type.toLowerCase();
    if (t.contains('robot')) { return AppColors.info; }
    if (t.contains('tales') ||
        t.contains('lectur') ||
        t.contains('benzi')) { return AppColors.warning; }
    if (t.contains('model') ||
        t.contains('imprim') ||
        t.contains('3d')) { return AppColors.success; }
    return AppColors.muted;
  }

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    final initials = parts.take(2).map((p) => p[0].toUpperCase()).join();
    final color = (workshopType != null && workshopType!.isNotEmpty)
        ? colorForWorkshopType(workshopType!)
        : colorForName(name);

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
