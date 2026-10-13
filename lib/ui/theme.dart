import 'package:flutter/material.dart';

import '../domain/baby.dart';

/// Soft, light themes. Each baby gets a gentle accent; "neutral" is sage green.
Color seedFor(Gender g) => switch (g) {
  Gender.girl => const Color(0xFFE58FA6),
  Gender.boy => const Color(0xFF6FA8D6),
  Gender.neutral => brandOrange,
};

/// The app's own colour, shared with the start screen and the icon.
const brandOrange = Color(0xFFC4420F);

/// Light and dark backgrounds, warm like the start screen.
const _creamLight = Color(0xFFFFF6EE);
const _creamDark = Color(0xFF1E1613);

/// The theme for [gender] that follows the phone's light or dark setting.
/// Use this for per-baby screens, which sit inside their own [Theme].
ThemeData themeFor(BuildContext context, Gender gender) =>
    buildTheme(gender, brightness: MediaQuery.platformBrightnessOf(context));

ThemeData buildTheme(
  Gender gender, {
  Brightness brightness = Brightness.light,
}) {
  final light = brightness == Brightness.light;
  var scheme = ColorScheme.fromSeed(
    seedColor: seedFor(gender),
    brightness: brightness,
  );
  if (gender == Gender.neutral) {
    // Exactly the start screen's orange (a lighter tone of it in dark mode).
    scheme = scheme.copyWith(
      primary: light ? brandOrange : const Color(0xFFFF8A5B),
      onPrimary: light ? Colors.white : const Color(0xFF3B1000),
      primaryContainer: light
          ? const Color(0xFFFFE1D1)
          : const Color(0xFF5A2410),
      onPrimaryContainer: light
          ? const Color(0xFF5A1E05)
          : const Color(0xFFFFE1D1),
    );
  }
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'DMSans',
    // DM Sans has no Greek or Cyrillic; fall back so those names still show.
    fontFamilyFallback: const ['NotoSans'],
    colorScheme: scheme,
    scaffoldBackgroundColor: light ? _creamLight : _creamDark,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'DMSans',
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: light ? Colors.white : const Color(0xFF2A201C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        textStyle: const TextStyle(
          fontFamily: 'DMSans',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: light ? Colors.white : const Color(0xFF2A201C),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
