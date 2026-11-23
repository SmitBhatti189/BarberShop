import 'package:flutter/material.dart';

/// Typography scale. Colours are applied by AppTheme per brightness.
///
/// Body text uses the platform default font. Page titles, headings and big
/// figures use **Fraunces** ([displayFontFamily]), a serif bundled in
/// `assets/fonts/` (SIL Open Font License) so the salon look is the same on
/// every platform, web included. Fraunces is a variable font: each display
/// style sets its weight and optical size through [display] — `fontWeight`
/// alone does not move a variable font's weight axis.
abstract final class AppTypography {
  static const String? fontFamily = null;

  static const String displayFontFamily = 'Fraunces';

  /// Used only if the bundled font cannot load.
  static const List<String> displayFontFallback = ['Georgia', 'Noto Serif', 'serif'];

  /// A Fraunces style at [size] px and [weight] (100–900), with the optical
  /// size axis matched to the size (finer details at large sizes).
  static TextStyle display(double size, double weight, {double? height, double? letterSpacing}) => TextStyle(
    fontFamily: displayFontFamily,
    fontFamilyFallback: displayFontFallback,
    fontSize: size,
    fontWeight: FontWeight.values[((weight / 100).round() - 1).clamp(0, 8)],
    fontVariations: [FontVariation.weight(weight), FontVariation.opticalSize(size.clamp(9, 144))],
    height: height,
    letterSpacing: letterSpacing,
  );

  static final TextTheme textTheme = TextTheme(
    displayMedium: display(44, 500, height: 1.1, letterSpacing: -0.5),
    displaySmall: display(32, 600, height: 1.2, letterSpacing: -0.3),
    headlineMedium: display(26, 600, height: 1.25),
    headlineSmall: display(22, 600, height: 1.3),
    titleLarge: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600, height: 1.3),
    titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4),
    titleSmall: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.4),
    bodyLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5),
    bodyMedium: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.45),
    bodySmall: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 1.4),
    labelLarge: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.1),
    labelMedium: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
    labelSmall: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.3),
  );

  /// Salon name next to the logo.
  static final TextStyle brandName = display(17, 600, height: 1.2);

  /// Small upper-case group labels (side menu sections, card captions).
  static const TextStyle overline = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    height: 1.3,
  );

  /// Figures in tables and bills line up when digits have equal width.
  static const List<FontFeature> tabularFigures = [FontFeature.tabularFigures()];
}
