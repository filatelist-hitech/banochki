import 'package:flutter/material.dart';

abstract final class BanochkiColors {
  static const canvas = Color(0xFFFFF8EE);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF241B16);
  static const mutedInk = Color(0xFF63564E);
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
  static const standard = 52.0;
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
  textTheme: Typography.material2021().black.apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(BanochkiRadius.card),
      side: BorderSide(color: scheme.outlineVariant),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(BanochkiRadius.control),
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
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(48, BanochkiTargets.standard),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BanochkiRadius.control),
      ),
      textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
    ),
  ),
);
