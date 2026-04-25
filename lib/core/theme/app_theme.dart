import 'package:flutter/material.dart';

/// Premium Islamic theme — "Midnight Oasis" (dark) & "Ivory Sanctuary" (light)
abstract final class AppTheme {
  // ─── Brand Colors ────────────────────────────────────────────────────────
  static const emerald = Color(0xFF10B981);
  static const emeraldDeep = Color(0xFF059669);
  static const gold = Color(0xFFD4A574);
  static const goldLight = Color(0xFFF0D9A8);
  static const teal = Color(0xFF14B8A6);

  // ─── Dark Palette ────────────────────────────────────────────────────────
  static const _dBg = Color(0xFF0D1520);
  static const _dSurface = Color(0xFF152032);
  static const _dCard = Color(0xFF1A2840);
  static const _dCardHigh = Color(0xFF1F3050);
  static const _dBorder = Color(0xFF253550);
  static const _dBorderSubtle = Color(0xFF1E2D44);
  static const _dTextPrimary = Color(0xFFE8EDF4);
  static const _dTextSecondary = Color(0xFF8899AD);
  static const _dTextTertiary = Color(0xFF5A6D85);

  // ─── Light Palette ───────────────────────────────────────────────────────
  static const _lBg = Color(0xFFF5F2EB);
  static const _lSurface = Color(0xFFFFFFFF);
  static const _lCard = Color(0xFFFFFFFF);
  static const _lBorder = Color(0xFFD6CEBD);
  static const _lBorderSubtle = Color(0xFFE8E3D8);
  static const _lTextPrimary = Color(0xFF1A1F2E);
  static const _lTextSecondary = Color(0xFF64748B);

  // ─── Dark Theme ──────────────────────────────────────────────────────────

  static ThemeData dark() {
    const colorScheme = ColorScheme.dark(
      brightness: Brightness.dark,
      primary: emerald,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFF064E3B),
      onPrimaryContainer: Color(0xFF6EE7B7),
      secondary: gold,
      onSecondary: Color(0xFF1A1A1A),
      secondaryContainer: Color(0xFF78350F),
      onSecondaryContainer: Color(0xFFFDE68A),
      tertiary: teal,
      surface: _dSurface,
      onSurface: _dTextPrimary,
      onSurfaceVariant: _dTextSecondary,
      surfaceContainerLowest: _dBg,
      surfaceContainerLow: Color(0xFF111C2C),
      surfaceContainer: _dCard,
      surfaceContainerHigh: _dCardHigh,
      outline: _dBorder,
      outlineVariant: _dBorderSubtle,
      error: Color(0xFFEF4444),
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _dBg,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _dBg,
        foregroundColor: _dTextPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: _dCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _dBorderSubtle),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: _dBorderSubtle,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _dSurface,
        indicatorColor: emerald.withValues(alpha: 0.15),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? emerald : _dTextTertiary,
            letterSpacing: 0.2,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? emerald : _dTextTertiary,
            size: 24,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _dCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _dBorderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _dBorderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: emerald, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: _dTextTertiary, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: emerald,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _dCardHigh,
        contentTextStyle: const TextStyle(color: _dTextPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _dSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: emerald,
      ),
    );
  }

  // ─── Light Theme ─────────────────────────────────────────────────────────

  static ThemeData light() {
    const primaryGreen = Color(0xFF15803D);
    const goldAccent = Color(0xFFC9A961);

    const colorScheme = ColorScheme.light(
      brightness: Brightness.light,
      primary: primaryGreen,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFDCFCE7),
      onPrimaryContainer: Color(0xFF14532D),
      secondary: goldAccent,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFFEF3C7),
      onSecondaryContainer: Color(0xFF78350F),
      tertiary: Color(0xFF0F766E),
      surface: _lSurface,
      onSurface: _lTextPrimary,
      onSurfaceVariant: _lTextSecondary,
      surfaceContainerLowest: _lBg,
      surfaceContainerLow: Color(0xFFFAF8F3),
      surfaceContainer: Color(0xFFF0ECE2),
      surfaceContainerHigh: Color(0xFFE8E3D8),
      outline: _lBorder,
      outlineVariant: _lBorderSubtle,
      error: Color(0xFFDC2626),
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _lBg,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _lBg,
        foregroundColor: _lTextPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: _lCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _lBorderSubtle),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: _lBorderSubtle,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _lSurface,
        indicatorColor: primaryGreen.withValues(alpha: 0.1),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? primaryGreen : const Color(0xFF9E9E9E),
            letterSpacing: 0.2,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? primaryGreen : const Color(0xFF9E9E9E),
            size: 24,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _lSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _lBorderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _lBorderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryGreen, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _lTextPrimary,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _lSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryGreen,
      ),
    );
  }
}
