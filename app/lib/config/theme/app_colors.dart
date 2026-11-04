import 'package:flutter/material.dart';

/// THE colour palette, one set per theme. Change a value here and it updates
/// everywhere. Screens never use `Color(0x…)` literals: they read
/// `Theme.of(context).colorScheme` or, for tokens Material has no slot for,
/// `AppColors.of(context)`.
///
/// Values marked "owner" come from the salon's colour spec; values marked
/// "assumed" were not in the spec and were chosen to match it.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.primaryButton,
    required this.primaryButtonText,
    required this.goldButton,
    required this.goldButtonText,
    required this.secondaryButton,
    required this.secondaryText,
    required this.hoverOverlay,
    required this.pressedOverlay,
    required this.disabledBackground,
    required this.disabledText,
    required this.fieldBackground,
    required this.fieldBorder,
    required this.focusBorder,
    required this.selectedItem,
    required this.selectedIcon,
    required this.unselectedIcon,
    required this.navigationBackground,
    required this.divider,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.onStatus,
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
  });

  static const light = AppColors(
    primaryButton: Color(0xFF202124), // owner
    primaryButtonText: Color(0xFFFFFFFF), // owner
    goldButton: Color(0xFFA47D43), // owner
    goldButtonText: Color(0xFFFFFFFF), // owner
    secondaryButton: Color(0xFFEDE2CE), // owner
    secondaryText: Color(0xFF72552E), // owner
    hoverOverlay: Color(0xFFE9E2D5), // owner
    pressedOverlay: Color(0xFFDCD3C3), // owner
    disabledBackground: Color(0xFFE7E3DC), // owner
    disabledText: Color(0xFFA29C91), // owner
    fieldBackground: Color(0xFFFFFFFF), // owner
    fieldBorder: Color(0xFFDED8CC), // owner
    focusBorder: Color(0xFFA47D43), // owner
    selectedItem: Color(0xFFEDE2CE), // owner
    selectedIcon: Color(0xFF806033), // owner
    unselectedIcon: Color(0xFF77736B), // owner
    navigationBackground: Color(0xFFFFFFFF), // owner
    divider: Color(0xFFDED8CC), // owner
    success: Color(0xFF397653), // owner
    warning: Color(0xFF956018), // owner
    error: Color(0xFFB33F3F), // owner
    info: Color(0xFF356DA6), // owner
    onStatus: Color(0xFFFFFFFF), // assumed
    background: Color(0xFFF7F5F1), // assumed: warm off-white page background
    surface: Color(0xFFFFFFFF), // assumed: cards and dialogs
    textPrimary: Color(0xFF202124), // assumed: matches primary button
    textSecondary: Color(0xFF77736B), // assumed: matches unselected icon
  );

  static const dark = AppColors(
    primaryButton: Color(0xFFD6B779), // owner
    primaryButtonText: Color(0xFF202124), // owner
    goldButton: Color(0xFFD6B779), // owner
    goldButtonText: Color(0xFF202124), // owner
    secondaryButton: Color(0xFF403625), // owner
    secondaryText: Color(0xFFE8D3A9), // owner
    hoverOverlay: Color(0xFF343538), // owner
    pressedOverlay: Color(0xFF45464A), // owner
    disabledBackground: Color(0xFF343538), // owner
    disabledText: Color(0xFF77746E), // owner
    fieldBackground: Color(0xFF252629), // owner
    fieldBorder: Color(0xFF3B3C40), // owner
    focusBorder: Color(0xFFD6B779), // owner
    selectedItem: Color(0xFF403625), // owner
    selectedIcon: Color(0xFFD6B779), // owner
    unselectedIcon: Color(0xFFA6A199), // owner
    navigationBackground: Color(0xFF202124), // owner
    divider: Color(0xFF3B3C40), // owner
    success: Color(0xFF82C49A), // owner
    warning: Color(0xFFE5B96D), // owner
    error: Color(0xFFF08C86), // owner
    info: Color(0xFF82B9ED), // owner
    onStatus: Color(0xFF202124), // assumed: dark text on the light status colours
    background: Color(0xFF18191B), // assumed: one step darker than navigation
    surface: Color(0xFF202124), // assumed: matches navigation background
    textPrimary: Color(0xFFECEAE6), // assumed
    textSecondary: Color(0xFFA6A199), // assumed: matches unselected icon
  );

  static AppColors of(BuildContext context) => Theme.of(context).extension<AppColors>()!;

  final Color primaryButton;
  final Color primaryButtonText;
  final Color goldButton;
  final Color goldButtonText;
  final Color secondaryButton;
  final Color secondaryText;
  final Color hoverOverlay;
  final Color pressedOverlay;
  final Color disabledBackground;
  final Color disabledText;
  final Color fieldBackground;
  final Color fieldBorder;
  final Color focusBorder;
  final Color selectedItem;
  final Color selectedIcon;
  final Color unselectedIcon;
  final Color navigationBackground;
  final Color divider;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  final Color onStatus;
  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;

  /// Hover / pressed feedback for surfaces (nav items, menus, text buttons).
  WidgetStateProperty<Color?> get overlay => WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.pressed)) return pressedOverlay;
    if (states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)) return hoverOverlay;
    return null;
  });

  // Appointment status chips.
  Color get statusScheduled => info;
  Color get statusConfirmed => selectedIcon;
  Color get statusInProgress => warning;
  Color get statusCompleted => success;
  Color get statusCancelled => disabledText;
  Color get statusNoShow => error;

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(AppColors? other, double t) => t < 0.5 || other == null ? this : other;
}
