/// Which elements show their name in a tooltip when the mouse hovers over
/// them (or on long-press on touch screens). Flip a switch here to turn a
/// hover label on or off everywhere.
abstract final class AppHoverLabels {
  /// Sidebar section icons while the sidebar is collapsed.
  static const bool sidebarItems = true;

  /// The collapse / expand button next to the logo.
  static const bool sidebarToggle = false;

  /// The logo and application name (click → Dashboard).
  static const bool appName = false;

  /// The profile box in the navbar.
  static const bool profileButton = false;
}
