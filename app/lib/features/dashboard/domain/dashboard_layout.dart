import '../../../core/auth/auth_models.dart';
import '../../../core/permissions.dart';
import '../../../core/router/app_destinations.dart';

/// What the dashboard shows, decided only by the signed-in person's
/// permissions (the backend re-checks every number it sends).
///
/// * Manager view — salon-wide: sales, all appointments, stock, staff pay.
/// * Staff view — own work only: my clients, my commission, my balance
///   (ARCHITECTURE §5.4: "No salon-wide financials").
///
/// Each item names the module that will supply its data. Until that module
/// is built the dashboard shows the item's place, never a made-up value.

/// One number at the top of the dashboard.
enum DashboardStat {
  salesToday('Sales today', 'Billing', highlighted: true),
  appointmentsToday('Appointments today', 'Appointments'),
  lowStock('Low stock', 'Inventory'),
  staffOwed('You owe staff', 'Staff & pay'),
  myClientsToday('My clients today', 'Appointments'),
  myCommissionToday('My commission today', 'Billing'),
  myBalance('My balance', 'My earnings', highlighted: true);

  const DashboardStat(this.label, this.module, {this.highlighted = false});

  final String label;

  /// Module whose data fills this number.
  final String module;

  /// Shown on the dark tile (the one number that matters most).
  final bool highlighted;
}

/// One card in the body of the dashboard.
enum DashboardPanel {
  chairsToday('Chairs today', "Every barber's bookings for today on one timeline.", AppDestinations.appointments),
  myDay('My day', 'Your bookings for today, with the client in your chair first.', AppDestinations.appointments),
  lowStock('Low stock', 'Products at or below their reorder level.', AppDestinations.inventory),
  staffBalances(
    'Staff balances',
    'Who owes whom right now: commission, salary and withdrawals.',
    AppDestinations.staff,
  ),
  myEarnings('My earnings', 'Commission this month, your balance and withdrawals.', AppDestinations.myEarnings);

  const DashboardPanel(this.title, this.description, this.destination);

  final String title;
  final String description;

  /// Section the panel's "Open" link goes to; its label names the module.
  final AppDestination destination;
}

/// Shortcut buttons; each opens the section where the action is done.
enum DashboardAction {
  newBill('New bill', AppDestinations.billing),
  newBooking('New booking', AppDestinations.appointments),
  addCustomer('Add customer', AppDestinations.customers),
  receiveStock('Receive stock', AppDestinations.inventory);

  const DashboardAction(this.label, this.destination);

  final String label;
  final AppDestination destination;
}

class DashboardLayout {
  const DashboardLayout({
    required this.stats,
    required this.mainPanels,
    required this.sidePanels,
    required this.actions,
  });

  final List<DashboardStat> stats;

  /// Wide left column (stacked first on phones).
  final List<DashboardPanel> mainPanels;

  /// Narrow right column.
  final List<DashboardPanel> sidePanels;
  final List<DashboardAction> actions;

  bool get isEmpty => stats.isEmpty && mainPanels.isEmpty && sidePanels.isEmpty && actions.isEmpty;
}

DashboardLayout dashboardLayoutFor(CurrentUser user) {
  final seesAllBookings = user.can(Permissions.appointmentsViewAll);
  final seesOwnBookings = !seesAllBookings && user.can(Permissions.appointmentsView);
  final seesSales = user.canAny([Permissions.billingView, Permissions.reportsFinancialView]);
  final seesStock = user.can(Permissions.inventoryView);
  final seesStaffPay = user.can(Permissions.compensationView);
  final seesOwnEarnings = user.can(Permissions.earningsViewOwn);

  return DashboardLayout(
    stats: [
      if (seesSales) DashboardStat.salesToday,
      if (seesAllBookings) DashboardStat.appointmentsToday,
      if (seesOwnBookings) DashboardStat.myClientsToday,
      if (seesOwnEarnings) DashboardStat.myCommissionToday,
      if (seesStock) DashboardStat.lowStock,
      if (seesStaffPay) DashboardStat.staffOwed,
      if (seesOwnEarnings) DashboardStat.myBalance,
    ],
    mainPanels: [if (seesAllBookings) DashboardPanel.chairsToday, if (seesOwnBookings) DashboardPanel.myDay],
    sidePanels: [
      if (seesStock) DashboardPanel.lowStock,
      if (seesStaffPay) DashboardPanel.staffBalances,
      if (seesOwnEarnings) DashboardPanel.myEarnings,
    ],
    actions: [
      if (user.can(Permissions.billingCreate)) DashboardAction.newBill,
      if (user.can(Permissions.appointmentsManage)) DashboardAction.newBooking,
      if (user.can(Permissions.customersManage)) DashboardAction.addCustomer,
      if (user.can(Permissions.inventoryManage)) DashboardAction.receiveStock,
    ],
  );
}
