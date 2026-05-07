import 'package:flutter/material.dart';

// ── Breakpoints ───────────────────────────────────────────────────────────────

const double kMobileBreakpoint = 600;
const double kTabletBreakpoint = 1100;

// ── Helper extension on BuildContext ─────────────────────────────────────────

extension ResponsiveContext on BuildContext {
  double get _w => MediaQuery.of(this).size.width;

  bool get isMobile => _w < kMobileBreakpoint;
  bool get isTablet => _w >= kMobileBreakpoint && _w < kTabletBreakpoint;
  bool get isDesktop => _w >= kTabletBreakpoint;

  /// Horizontal padding for top-level page content.
  EdgeInsets get mobilePadding =>
      isMobile ? const EdgeInsets.fromLTRB(16, 8, 16, 40) : const EdgeInsets.fromLTRB(20, 8, 20, 40);

  /// Padding inside cards.
  EdgeInsets get cardPadding =>
      isMobile ? const EdgeInsets.all(14) : const EdgeInsets.all(20);

  /// Standard vertical spacing between sections.
  double get sectionGap => isMobile ? 12.0 : 16.0;

  /// Card border radius.
  double get cardRadius => isMobile ? 14.0 : 16.0;
}
