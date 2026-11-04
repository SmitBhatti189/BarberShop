import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_sizes.dart';
import 'app_spacing.dart';

/// Button variants. `AppButton` picks one of these.
/// * primary   — main action (charcoal in light mode, gold in dark mode)
/// * gold      — highlighted action (e.g. "Collect payment")
/// * secondary — soft beige alternative action
/// * danger    — destructive action
/// * text      — low-emphasis action
enum AppButtonVariant { primary, gold, secondary, danger, text }

enum AppButtonSize { regular, small }

abstract final class AppButtonStyles {
  static const OutlinedBorder shape = RoundedRectangleBorder(borderRadius: AppRadius.button);

  static Size minimumSize(AppButtonSize size) =>
      Size(AppSizes.buttonMinWidth, size == AppButtonSize.small ? AppSizes.buttonHeightSmall : AppSizes.buttonHeight);

  static EdgeInsets padding(AppButtonSize size) =>
      EdgeInsets.symmetric(horizontal: size == AppButtonSize.small ? AppSpacing.md : AppSpacing.xl);

  static ButtonStyle of(BuildContext context, AppButtonVariant variant, AppButtonSize size) {
    final c = AppColors.of(context);
    final (bg, fg) = switch (variant) {
      AppButtonVariant.primary => (c.primaryButton, c.primaryButtonText),
      AppButtonVariant.gold => (c.goldButton, c.goldButtonText),
      AppButtonVariant.secondary => (c.secondaryButton, c.secondaryText),
      AppButtonVariant.danger => (c.error, c.onStatus),
      AppButtonVariant.text => (Colors.transparent, c.secondaryText),
    };
    return filled(c, background: bg, foreground: fg, size: size, textStyle: Theme.of(context).textTheme.labelLarge);
  }

  /// Shared recipe: solid background, overlay tint on hover/press, the
  /// owner's disabled colours, rounded shape.
  static ButtonStyle filled(
    AppColors c, {
    required Color background,
    required Color foreground,
    AppButtonSize size = AppButtonSize.regular,
    TextStyle? textStyle,
  }) {
    final isText = background == Colors.transparent;
    return ButtonStyle(
      shape: const WidgetStatePropertyAll(shape),
      minimumSize: WidgetStatePropertyAll(minimumSize(size)),
      padding: WidgetStatePropertyAll(padding(size)),
      textStyle: WidgetStatePropertyAll(textStyle),
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return isText ? Colors.transparent : c.disabledBackground;
        return background;
      }),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled) ? c.disabledText : foreground,
      ),
      iconColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled) ? c.disabledText : foreground,
      ),
      // Text buttons use the overlay colours as-is; on solid buttons they are
      // blended in lightly so the label stays readable.
      overlayColor: isText
          ? c.overlay
          : WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.pressed)) return c.pressedOverlay.withValues(alpha: 0.28);
              if (states.contains(WidgetState.hovered)) return c.hoverOverlay.withValues(alpha: 0.20);
              return null;
            }),
    );
  }
}
