import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Brand (logo blue) ───────────────────────────────────────────────────────
  /// Primary brand blue, #028FE3 — use for buttons, active accents, icons.
  static const Color purple = Color(0xFF028FE3);
  static const Color purpleDark = Color(0xFF0073C4);
  static const Color purpleLight = Color(0xFFDDF2FF);

  // ── Sidebar adaptive colors ─────────────────────────────────────────────────
  static const Color sidebarLightBg = Color(0xFFFFFFFF);
  static const Color sidebarDarkBg = Color(0xFF0B1228);
  static const Color navActiveLightBg = Color(0xFFDDF2FF);
  static const Color navActiveDarkBg = Color(0xFF123A5A);
  /// Lighter accent for dark-mode sidebar text/icons (readable on dark navy).
  static const Color navAccentDark = Color(0xFF38BDF8);

  // ── Semantic ────────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);
  static const Color teal = Color(0xFF14B8A6);
  static const Color muted = Color(0xFF94A3B8);
  /// Orange used for DEMO workshop badges.
  static const Color demoBadge = Color(0xFFF97316);

  // ── Light palette ───────────────────────────────────────────────────────────
  static const Color bgLight = Color(0xFFF5F8FC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE2E8F0);

  // ── Dark palette (clean navy, no purple tint) ───────────────────────────────
  static const Color bgDark = Color(0xFF070B1F);
  static const Color surfaceDark = Color(0xFF11172F);
  static const Color borderDark = Color(0xFF1E2A45);
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final cs = ColorScheme.fromSeed(
      seedColor: AppColors.purple,
      brightness: Brightness.light,
      primary: AppColors.purple,
      onPrimary: Colors.white,
      secondary: AppColors.purpleDark,
      surface: AppColors.surfaceLight,
      onSurface: const Color(0xFF101828),
      surfaceContainerHighest: AppColors.bgLight,
      outline: const Color(0xFF667085),
      error: AppColors.error,
    );

    return ThemeData(
      colorScheme: cs,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.bgLight,
      fontFamily: 'Inter',
      cardTheme: CardThemeData(
        color: AppColors.surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderLight),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: Color(0xFF1A1A2E),
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.purple, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.purple,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.purple,
          side: const BorderSide(color: AppColors.purple),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderLight,
        space: 1,
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide.none,
        backgroundColor: AppColors.purpleLight,
        labelStyle: const TextStyle(
          color: AppColors.purple,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }

  static ThemeData dark() {
    final cs = ColorScheme.fromSeed(
      seedColor: AppColors.purple,
      brightness: Brightness.dark,
      primary: AppColors.navAccentDark,
      onPrimary: const Color(0xFF001A2E),
      secondary: AppColors.purple,
      surface: AppColors.surfaceDark,
      onSurface: const Color(0xFFF8FAFC),
      surfaceContainerHighest: AppColors.bgDark,
      outline: const Color(0xFF94A3B8),
      error: AppColors.error,
    );

    return ThemeData(
      colorScheme: cs,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.bgDark,
      fontFamily: 'Inter',
      cardTheme: CardThemeData(
        color: AppColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderDark),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surfaceDark,
        foregroundColor: Color(0xFFF8FAFC),
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.navAccentDark, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.navAccentDark,
          foregroundColor: const Color(0xFF001A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navAccentDark,
          side: const BorderSide(color: AppColors.navAccentDark),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderDark,
        space: 1,
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide.none,
        backgroundColor: AppColors.navAccentDark.withValues(alpha: 0.15),
        labelStyle: const TextStyle(
          color: AppColors.navAccentDark,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }
}

