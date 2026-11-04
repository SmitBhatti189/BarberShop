/// Component sizes and layout breakpoints.
abstract final class AppSizes {
  // Buttons (touch-friendly: ≥ 48 on mobile per Material guidance)
  static const double buttonHeight = 48;
  static const double buttonHeightSmall = 36;
  static const double buttonMinWidth = 88;

  // Icons
  static const double iconSm = 16;
  static const double iconMd = 20;
  static const double iconLg = 24;
  static const double iconXl = 40;

  // Inputs
  static const double fieldHeight = 48;

  // Content width caps so forms don't stretch across a desktop monitor.
  static const double formMaxWidth = 480;
  static const double contentMaxWidth = 1280;
  static const double dialogMaxWidth = 520;

  // Navigation
  static const double navBarHeight = 60;
  static const double sidebarCollapsedWidth = 80; // fits logo + toggle side by side
  static const double sidebarToggleSize = 36;
  static const double sidebarExpandedWidth = 248;
  static const double sidebarItemHeight = 44;
  static const double avatarSize = 32;
  static const double profileMenuWidth = 260;

  // Breakpoints (logical width)
  static const double compactMax = 600; // phones
  static const double mediumMax = 1200; // tablets, small windows
}
