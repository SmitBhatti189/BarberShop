import 'package:barbershop_app/core/auth/auth_models.dart';
import 'package:barbershop_app/core/permissions.dart';
import 'package:barbershop_app/features/dashboard/domain/dashboard_layout.dart';
import 'package:barbershop_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

CurrentUser withPermissions(Set<String> permissions) =>
    CurrentUser(id: 9, fullName: 'Test Person', branchId: 1, roleId: 9, permissions: permissions);

final manager = withPermissions({
  Permissions.appointmentsViewAll,
  Permissions.appointmentsManage,
  Permissions.billingView,
  Permissions.billingCreate,
  Permissions.inventoryView,
  Permissions.inventoryManage,
  Permissions.compensationView,
  Permissions.customersManage,
});

final barber = withPermissions({
  Permissions.appointmentsView,
  Permissions.billingCreate,
  Permissions.earningsViewOwn,
  Permissions.withdrawalsRequestOwn,
});

void setScreen(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget dashboard(CurrentUser user) => harness(FakeAuthController(AuthSignedIn(user)), const DashboardScreen());

void main() {
  group('dashboardLayoutFor', () {
    test('manager sees the salon: sales, all bookings, stock, staff pay', () {
      final layout = dashboardLayoutFor(manager);
      expect(layout.stats, [
        DashboardStat.salesToday,
        DashboardStat.appointmentsToday,
        DashboardStat.lowStock,
        DashboardStat.staffOwed,
      ]);
      expect(layout.mainPanels, [DashboardPanel.chairsToday]);
      expect(layout.sidePanels, [DashboardPanel.lowStock, DashboardPanel.staffBalances]);
      expect(layout.actions, [
        DashboardAction.newBill,
        DashboardAction.newBooking,
        DashboardAction.addCustomer,
        DashboardAction.receiveStock,
      ]);
    });

    test('barber sees only their own work — no salon-wide money', () {
      final layout = dashboardLayoutFor(barber);
      expect(layout.stats, [DashboardStat.myClientsToday, DashboardStat.myCommissionToday, DashboardStat.myBalance]);
      expect(layout.stats, isNot(contains(DashboardStat.salesToday)));
      expect(layout.stats, isNot(contains(DashboardStat.staffOwed)));
      expect(layout.mainPanels, [DashboardPanel.myDay]);
      expect(layout.sidePanels, [DashboardPanel.myEarnings]);
      expect(layout.actions, [DashboardAction.newBill]);
    });

    test('seeing all bookings replaces the own-bookings view', () {
      final layout = dashboardLayoutFor(
        withPermissions({Permissions.appointmentsView, Permissions.appointmentsViewAll}),
      );
      expect(layout.mainPanels, [DashboardPanel.chairsToday]);
      expect(layout.stats, [DashboardStat.appointmentsToday]);
    });

    test('no relevant permissions → empty dashboard', () {
      expect(dashboardLayoutFor(withPermissions({})).isEmpty, isTrue);
    });
  });

  testWidgets('manager dashboard: tiles show no made-up numbers, panels name their module', (tester) async {
    setScreen(tester, const Size(1200, 1000));
    await tester.pumpWidget(dashboard(manager));
    await tester.pumpAndSettle();

    expect(find.text('Sales today'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(4)); // every tile is a placeholder value
    expect(find.text('Shows once Billing is built'), findsOneWidget);
    expect(find.byKey(const Key('panel-chairsToday')), findsOneWidget);
    expect(find.text('Appears when the Appointments module is built.'), findsOneWidget);
    expect(find.byKey(const Key('action-newBill')), findsOneWidget);
    // Wide screen: the side column sits to the right of the main column.
    expect(
      tester.getTopLeft(find.byKey(const Key('panel-quick-actions'))).dx,
      greaterThan(tester.getTopLeft(find.byKey(const Key('panel-chairsToday'))).dx),
    );
  });

  testWidgets('barber dashboard on a phone: own numbers only, one column', (tester) async {
    setScreen(tester, const Size(375, 1400));
    await tester.pumpWidget(dashboard(barber));
    await tester.pumpAndSettle();

    expect(find.text('My balance'), findsOneWidget);
    expect(find.text('Sales today'), findsNothing);
    expect(find.text('You owe staff'), findsNothing);
    expect(find.byKey(const Key('panel-myDay')), findsOneWidget);
    // Phone: cards stack, all starting at the same left edge.
    expect(
      tester.getTopLeft(find.byKey(const Key('panel-quick-actions'))).dx,
      tester.getTopLeft(find.byKey(const Key('panel-myDay'))).dx,
    );
  });

  testWidgets('greets the person by first name', (tester) async {
    setScreen(tester, const Size(1200, 1000));
    await tester.pumpWidget(dashboard(barber));
    await tester.pumpAndSettle();
    expect(find.textContaining(', Test'), findsOneWidget);
  });
}
