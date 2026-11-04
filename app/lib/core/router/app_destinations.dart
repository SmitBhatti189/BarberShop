import 'package:flutter/widgets.dart';

import '../../config/assets/app_icons.dart';
import '../auth/auth_models.dart';
import '../permissions.dart';

/// Every top-level section of the app, in menu order. Navigation menus and
/// route guards are both derived from this list, so adding a module means
/// adding one entry here and one route in app_router.dart.
class AppDestination {
  const AppDestination({
    required this.path,
    required this.label,
    required this.icon,
    this.anyOf = const [],
    this.primaryOnMobile = false,
    this.shortLabel,
    this.inMenu = true,
  });

  /// False for sections reached elsewhere (e.g. Settings, from the profile
  /// box). The route and its permission check still apply.
  final bool inMenu;

  final String path;
  final String label;

  /// Fits the narrow phone bottom bar (defaults to [label]).
  final String? shortLabel;
  final IconData icon;

  /// Visible when the user has ANY of these permissions (empty = everyone).
  final List<String> anyOf;

  /// Shown in the phone bottom bar (max 4) instead of under "More".
  final bool primaryOnMobile;

  bool isVisibleTo(CurrentUser user) => anyOf.isEmpty || user.canAny(anyOf);
}

abstract final class AppDestinations {
  static const dashboard = AppDestination(
    path: '/dashboard',
    label: 'Dashboard',
    icon: AppIcons.dashboard,
    primaryOnMobile: true,
  );
  static const appointments = AppDestination(
    path: '/appointments',
    label: 'Appointments',
    shortLabel: 'Bookings',
    icon: AppIcons.appointments,
    anyOf: [Permissions.appointmentsView, Permissions.appointmentsViewAll],
    primaryOnMobile: true,
  );
  static const billing = AppDestination(
    path: '/billing',
    label: 'Billing',
    icon: AppIcons.billing,
    anyOf: [Permissions.billingCreate, Permissions.billingView],
    primaryOnMobile: true,
  );
  static const customers = AppDestination(
    path: '/customers',
    label: 'Customers',
    icon: AppIcons.customers,
    anyOf: [Permissions.customersView],
    primaryOnMobile: true,
  );
  static const myEarnings = AppDestination(
    path: '/my-earnings',
    label: 'My earnings',
    icon: AppIcons.earnings,
    anyOf: [Permissions.earningsViewOwn],
  );
  static const services = AppDestination(
    path: '/services',
    label: 'Services',
    icon: AppIcons.services,
    anyOf: [Permissions.servicesView],
  );
  static const inventory = AppDestination(
    path: '/inventory',
    label: 'Inventory',
    icon: AppIcons.inventory,
    anyOf: [Permissions.inventoryView],
  );
  static const staff = AppDestination(
    path: '/staff',
    label: 'Staff & pay',
    icon: AppIcons.staff,
    anyOf: [Permissions.staffView, Permissions.compensationView],
  );
  static const roles = AppDestination(
    path: '/roles',
    label: 'Roles',
    icon: AppIcons.roles,
    anyOf: [Permissions.rolesManage],
  );
  static const settings = AppDestination(
    path: '/settings',
    label: 'Settings',
    icon: AppIcons.settings,
    anyOf: [Permissions.settingsManage],
    inMenu: false, // opened from the profile box
  );

  static const all = [
    dashboard,
    appointments,
    billing,
    customers,
    myEarnings,
    services,
    inventory,
    staff,
    roles,
    settings,
  ];

  /// Sections shown in the sidebar / bottom bar for [user].
  static List<AppDestination> menuFor(CurrentUser user) => all.where((d) => d.inMenu && d.isVisibleTo(user)).toList();

  /// The destination owning [location] (e.g. `/customers/12` → customers).
  static AppDestination? forLocation(String location) {
    for (final d in all) {
      if (location == d.path || location.startsWith('${d.path}/')) return d;
    }
    return null;
  }
}
