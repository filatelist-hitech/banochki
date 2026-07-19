import 'package:flutter/material.dart';

abstract final class BanochkiColors {
  static const canvas = Color(0xFFFFF8EE);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF241B16);
  static const mutedInk = Color(0xFF63564E);
  static const outline = Color(0xFF8D7B71);
  static const primary = Color(0xFF943F27);
  static const support = Color(0xFF3F6A52);
  static const attention = Color(0xFF8A4B08);
  static const danger = Color(0xFF982D2D);
}

abstract final class BanochkiSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

abstract final class BanochkiRadius {
  static const control = 12.0;
  static const card = 18.0;
}

abstract final class BanochkiTargets {
  static const standard = 56.0;
  static const large = 64.0;
}

ThemeData banochkiLightTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: BanochkiColors.primary,
        brightness: Brightness.light,
        surface: BanochkiColors.surface,
      ).copyWith(
        primary: BanochkiColors.primary,
        onPrimary: Colors.white,
        secondary: BanochkiColors.support,
        error: BanochkiColors.danger,
        onSurface: BanochkiColors.ink,
        surfaceContainerLowest: BanochkiColors.canvas,
      );
  return _baseTheme(
    scheme,
  ).copyWith(scaffoldBackgroundColor: BanochkiColors.canvas);
}

ThemeData banochkiDarkTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFFE59A7F),
        brightness: Brightness.dark,
      ).copyWith(
        primary: const Color(0xFFFFB69C),
        onPrimary: const Color(0xFF561E10),
        secondary: const Color(0xFFA9D5B8),
      );
  return _baseTheme(scheme);
}

ThemeData _baseTheme(ColorScheme scheme) => ThemeData(
  useMaterial3: true,
  colorScheme: scheme,
  fontFamily: 'Roboto',
  textTheme: Typography.material2021().black.apply(
    fontFamily: 'Roboto',
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  ),
  cardTheme: CardThemeData(
    color: BanochkiColors.surface,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(BanochkiRadius.card),
      side: const BorderSide(color: BanochkiColors.outline),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: BanochkiColors.surface,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: BanochkiSpacing.md,
      vertical: BanochkiSpacing.md,
    ),
    labelStyle: const TextStyle(color: BanochkiColors.mutedInk),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(BanochkiRadius.control),
      borderSide: const BorderSide(color: BanochkiColors.outline),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(BanochkiRadius.control),
      borderSide: const BorderSide(color: BanochkiColors.outline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(BanochkiRadius.control),
      borderSide: const BorderSide(color: BanochkiColors.primary, width: 2),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      minimumSize: const Size(48, BanochkiTargets.standard),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BanochkiRadius.control),
      ),
      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, BanochkiTargets.standard),
      backgroundColor: BanochkiColors.primary,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BanochkiRadius.card),
      ),
      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(48, BanochkiTargets.standard),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BanochkiRadius.control),
      ),
      textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
    ),
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: scheme.onSurface,
    elevation: 0,
    scrolledUnderElevation: 0,
    titleTextStyle: TextStyle(
      color: scheme.onSurface,
      fontSize: 30,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.7,
    ),
  ),
  navigationBarTheme: NavigationBarThemeData(
    height: 76,
    backgroundColor: scheme.surface,
    indicatorColor: Colors.transparent,
    iconTheme: WidgetStateProperty.resolveWith(
      (states) => IconThemeData(
        color: states.contains(WidgetState.selected)
            ? BanochkiColors.primary
            : scheme.onSurfaceVariant,
      ),
    ),
    labelTextStyle: WidgetStateProperty.resolveWith(
      (states) => TextStyle(
        color: states.contains(WidgetState.selected)
            ? BanochkiColors.primary
            : scheme.onSurfaceVariant,
        fontWeight: states.contains(WidgetState.selected)
            ? FontWeight.w700
            : FontWeight.w500,
      ),
    ),
  ),
);
