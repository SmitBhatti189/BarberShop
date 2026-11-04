import 'package:flutter/material.dart';

/// Typography scale. Uses the platform default font (no bundled font files —
/// keeps the app small). Colours are applied by AppTheme per brightness.
abstract final class AppTypography {
  static const String? fontFamily = null;

  static const TextTheme textTheme = TextTheme(
    displaySmall: TextStyle(fontSize: 32, fontWeight: FontWeight.w600, height: 1.2),
    headlineMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, height: 1.25),
    headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.3),
    titleLarge: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, height: 1.3),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4),
    titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.4),
    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.45),
    bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 1.4),
    labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.1),
    labelMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
    labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.3),
  );

  /// Figures in tables and bills line up when digits have equal width.
  static const List<FontFeature> tabularFigures = [FontFeature.tabularFigures()];
}
