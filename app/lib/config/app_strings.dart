/// App-wide labels. Feature-specific copy stays with its feature.
abstract final class AppStrings {
  static const String appName = 'Barbershop Manager';
  static const String currencySymbol = '₹';

  /// Login brand panel.
  static const String tagline = 'Bookings, bills and chairs — in one place.';
  static const String taglineDetail = 'Sign in on any salon device connected to the shop Wi-Fi.';

  static const String retry = 'Retry';
  static const String cancel = 'Cancel';
  static const String confirm = 'Confirm';
  static const String save = 'Save';
  static const String logout = 'Log out';

  static const String genericError = 'Something went wrong. Please try again.';
  static const String networkError = 'Cannot reach the server. Check the Wi-Fi and that the server PC is on.';
  static const String sessionExpired = 'Your session has expired. Please log in again.';
  static const String notPermitted = 'You do not have permission to open that page.';
  static const String notImplemented = 'This module is planned and not built yet.';
}
