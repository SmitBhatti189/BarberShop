import 'package:flutter/material.dart';

import '../../config/theme/app_button_styles.dart';
import '../../config/theme/app_sizes.dart';

export '../../config/theme/app_button_styles.dart' show AppButtonSize, AppButtonVariant;

/// The app's one button. While [loading] it shows a spinner and ignores taps,
/// which also prevents double submission (e.g. paying a bill twice).
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.regular,
    this.icon,
    this.loading = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final bool loading;

  /// Fill the available width (forms on phones).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final style = AppButtonStyles.of(context, variant, size);
    final onTap = loading ? null : onPressed;
    final Widget content = loading
        ? const SizedBox.square(dimension: AppSizes.iconMd, child: CircularProgressIndicator(strokeWidth: 2))
        : Text(label);
    final leading = icon == null || loading ? null : Icon(icon, size: AppSizes.iconMd);

    final Widget button = switch (variant) {
      AppButtonVariant.primary || AppButtonVariant.gold || AppButtonVariant.secondary || AppButtonVariant.danger =>
        leading == null
            ? FilledButton(style: style, onPressed: onTap, child: content)
            : FilledButton.icon(style: style, onPressed: onTap, icon: leading, label: content),
      AppButtonVariant.text =>
        leading == null
            ? TextButton(style: style, onPressed: onTap, child: content)
            : TextButton.icon(style: style, onPressed: onTap, icon: leading, label: content),
    };
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
