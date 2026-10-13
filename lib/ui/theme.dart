import 'package:flutter/material.dart';

import '../domain/baby.dart';

/// Soft, light themes. Each baby gets a gentle accent; "neutral" is sage green.
Color seedFor(Gender g) => switch (g) {
  Gender.girl => const Color(0xFFE58FA6),
  Gender.boy => const Color(0xFF6FA8D6),
  Gender.neutral => const Color(0xFF7FB69E),
};

ThemeData buildTheme(
  Gender gender, {
  Brightness brightness = Brightness.light,
}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: seedFor(gender),
    brightness: brightness,
  );
  final light = brightness == Brightness.light;
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'DMSans',
    // DM Sans has no Greek or Cyrillic; fall back so those names still show.
    fontFamilyFallback: const ['NotoSans'],
    colorScheme: scheme,
    scaffoldBackgroundColor: light
        ? const Color(0xFFFFFAF5)
        : const Color(0xFF1B1A19),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: light ? Colors.white : const Color(0xFF262524),
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
      fillColor: light ? Colors.white : const Color(0xFF262524),
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
