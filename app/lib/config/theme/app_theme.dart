import 'package:flutter/material.dart';

import 'app_button_styles.dart';
import 'app_colors.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Builds ThemeData for light and dark mode from [AppColors]. This is the
/// only place colour tokens are turned into Material theming.
abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light, AppColors.light);

  static ThemeData dark() => _build(Brightness.dark, AppColors.dark);

  static ThemeData _build(Brightness brightness, AppColors c) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.primaryButton,
      onPrimary: c.primaryButtonText,
      secondary: c.goldButton,
      onSecondary: c.goldButtonText,
      secondaryContainer: c.secondaryButton,
      onSecondaryContainer: c.secondaryText,
      tertiary: c.selectedIcon,
      onTertiary: c.primaryButtonText,
      error: c.error,
      onError: c.onStatus,
      surface: c.surface,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      surfaceContainerLowest: c.fieldBackground,
      surfaceContainerHighest: c.hoverOverlay,
      outline: c.fieldBorder,
      outlineVariant: c.divider,
    );
    final textTheme = AppTypography.textTheme.apply(
      fontFamily: AppTypography.fontFamily,
      bodyColor: c.textPrimary,
      displayColor: c.textPrimary,
    );
    final primaryButton = AppButtonStyles.filled(c, background: c.primaryButton, foreground: c.primaryButtonText);
    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
      borderRadius: AppRadius.field,
      borderSide: BorderSide(color: color, width: width),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: [c],
      scaffoldBackgroundColor: c.background,
      canvasColor: c.surface,
      textTheme: textTheme,
      hoverColor: c.hoverOverlay,
      highlightColor: c.pressedOverlay,
      splashColor: c.pressedOverlay,
      focusColor: c.hoverOverlay,
      disabledColor: c.disabledText,
      dividerColor: c.divider,
      dividerTheme: DividerThemeData(color: c.divider, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: c.unselectedIcon),
      appBarTheme: AppBarTheme(
        backgroundColor: c.navigationBackground,
        foregroundColor: c.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: BorderSide(color: c.divider),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.fieldBackground,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        border: border(c.fieldBorder),
        enabledBorder: border(c.fieldBorder),
        disabledBorder: border(c.disabledBackground),
        focusedBorder: border(c.focusBorder, 2),
        errorBorder: border(c.error),
        focusedErrorBorder: border(c.error, 2),
        labelStyle: TextStyle(color: c.textSecondary),
        floatingLabelStyle: WidgetStateTextStyle.resolveWith(
          (states) => TextStyle(color: states.contains(WidgetState.focused) ? c.focusBorder : c.textSecondary),
        ),
        hintStyle: TextStyle(color: c.disabledText),
        prefixIconColor: c.unselectedIcon,
        suffixIconColor: c.unselectedIcon,
        errorStyle: TextStyle(color: c.error),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.focusBorder,
        selectionColor: c.focusBorder.withValues(alpha: 0.3),
        selectionHandleColor: c.focusBorder,
      ),
      filledButtonTheme: FilledButtonThemeData(style: primaryButton),
      elevatedButtonTheme: ElevatedButtonThemeData(style: primaryButton),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: AppButtonStyles.filled(c, background: c.secondaryButton, foreground: c.secondaryText),
      ),
      textButtonTheme: TextButtonThemeData(
        style: AppButtonStyles.filled(c, background: Colors.transparent, foreground: c.secondaryText),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(foregroundColor: WidgetStatePropertyAll(c.unselectedIcon), overlayColor: c.overlay),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.primaryButtonText : c.unselectedIcon,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? c.primaryButton : c.disabledBackground,
        ),
        trackOutlineColor: WidgetStatePropertyAll(c.fieldBorder),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.goldButton),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.dialog),
        titleTextStyle: textTheme.titleLarge,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: BorderSide(color: c.divider),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(c.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: AppRadius.card,
              side: BorderSide(color: c.divider),
            ),
          ),
        ),
      ),
      menuButtonTheme: MenuButtonThemeData(style: ButtonStyle(overlayColor: c.overlay)),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: c.primaryButton, borderRadius: AppRadius.button),
        textStyle: textTheme.labelMedium?.copyWith(color: c.primaryButtonText),
        waitDuration: const Duration(milliseconds: 250),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.primaryButton,
        contentTextStyle: TextStyle(color: c.primaryButtonText),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.navigationBackground,
        indicatorColor: c.selectedItem,
        surfaceTintColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(color: states.contains(WidgetState.selected) ? c.selectedIcon : c.unselectedIcon),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected) ? c.selectedIcon : c.textSecondary,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: c.surface, surfaceTintColor: Colors.transparent),
      listTileTheme: ListTileThemeData(iconColor: c.unselectedIcon, textColor: c.textPrimary),
      visualDensity: VisualDensity.standard,
    );
  }
}
