import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Canonical mapping from a `workshop_type` string to its visual
/// signature (`icon`, `color`). Single source of truth across the app:
///
///   • Robotică    → `Icons.precision_manufacturing_outlined` + blue
///   • Lectură     → `Icons.menu_book_outlined`             + amber/yellow
///   • Modelare 3D → `Icons.view_in_ar_outlined`            + teal
///   • Tales / Povestiri → `Icons.auto_stories_outlined`    + orange
///   • Desen / Pictură / Culoare → `Icons.draw_outlined`    + brand blue
///   • anything else → `Icons.event_outlined`               + brand blue
///
/// Used by every surface that renders a workshop visually:
///   - staff dashboard rows via `DashboardWorkshopItem`
///   - staff demo dashboard card via `DemoDashboardCard`
///   - parent dashboard child card via `ParentChildCard`
///   - parent weekly schedule via `DashboardWorkshopItem` (shared)
///
/// Callers destructure the record:
///
///     final (icon, color) = workshopTypeStyle(workshop.workshopType);
(IconData, Color) workshopTypeStyle(String type) {
  final t = type.toLowerCase();
  if (t.contains('robotic')) {
    return (Icons.precision_manufacturing_outlined, AppColors.info);
  }
  if (t.contains('lectur')) {
    return (Icons.menu_book_outlined, AppColors.warning);
  }
  if (t.contains('modela')) {
    return (Icons.view_in_ar_outlined, AppColors.teal);
  }
  if (t.contains('tales') || t.contains('povestiri')) {
    return (Icons.auto_stories_outlined, AppColors.demoBadge);
  }
  if (t.contains('desen') || t.contains('pictur') || t.contains('culoare')) {
    return (Icons.draw_outlined, AppColors.purple);
  }
  return (Icons.event_outlined, AppColors.purple);
}
