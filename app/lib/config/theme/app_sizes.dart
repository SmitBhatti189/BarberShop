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

  // Employee form: details and sign-in side by side from this content width.
  static const double employeeFormTwoColumnMin = 720;
  static const double employeeFormMaxWidth = 960;

  // Navigation
  static const double navBarHeight = 64;
  static const double brandMarkSize = 34; // gold square with the scissors
  static const double brandMarkSmall = 28; // collapsed side menu (fits beside the toggle)
  static const double brandMarkLarge = 44; // login brand panel
  static const double authPanelWidth = 520; // dark brand panel on wide login screens
  static const double authWideMin = 900; // below this the login is a single column
  static const double authFormMaxWidth = 400;

  // Dashboard
  static const double statTileMinHeight = 116;
  static const double statTileMinWidth = 200; // fewer tiles per row below this
  static const double dashboardTwoColumnMin = 860; // content width for main + side columns
  static const double dashboardSideWidth = 340;
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
