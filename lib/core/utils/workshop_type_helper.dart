import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Maps a workshop type string to a brand color and a representative icon.
/// All comparisons are case-insensitive and use substring matching so that
/// variations (e.g. "Robotică", "robotics") resolve consistently.
abstract final class WorkshopTypeHelper {
  static Color colorForType(String? type) {
    final t = (type ?? '').toLowerCase();
    if (t.contains('robotic')) return AppColors.info;
    if (t.contains('lectur') || t.contains('tales')) return AppColors.warning;
    if (t.contains('modela')) return AppColors.teal;
    if (t.contains('desen') || t.contains('pictur')) return AppColors.purple;
    return AppColors.purple;
  }

  static IconData iconForType(String? type) {
    final t = (type ?? '').toLowerCase();
    if (t.contains('robotic')) return Icons.precision_manufacturing_outlined;
    if (t.contains('lectur') || t.contains('tales') || t.contains('povestiri')) {
      return Icons.menu_book_outlined;
    }
    if (t.contains('modela')) return Icons.view_in_ar_outlined;
    if (t.contains('desen') || t.contains('pictur') || t.contains('culoare')) {
      return Icons.draw_outlined;
    }
    return Icons.event_outlined;
  }
}
