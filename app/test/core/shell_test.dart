import 'package:barbershop_app/config/theme/app_colors.dart';
import 'package:barbershop_app/config/theme/app_theme.dart';
import 'package:barbershop_app/core/auth/auth_controller.dart';
import 'package:barbershop_app/core/auth/auth_models.dart';
import 'package:barbershop_app/core/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:barbershop_app/core/router/app_shell.dart';
import 'package:barbershop_app/core/router/app_sidebar.dart';
import 'package:barbershop_app/core/storage/secure_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void setScreen(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget shell(FakeAuthController controller, {InMemorySecureStore? store}) => harness(
  controller,
  const AppShell(location: '/dashboard', child: SizedBox()),
  store: store,
);

void main() {
  testWidgets('phone: navbar on top, permitted sections in the bottom bar', (tester) async {
    setScreen(tester, const Size(375, 812));
    await tester.pumpWidget(shell(FakeAuthController(AuthSignedIn(staffUser()))));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(AppSidebar), findsNothing);
    expect(find.text('Bookings'), findsOneWidget); // short label fits on phones
    expect(find.text('Settings'), findsNothing);
    expect(find.byKey(const Key('sidebar-toggle')), findsNothing);
    expect(find.byKey(const Key('profile-button')), findsOneWidget);
    // No sidebar on phones, so the brand sits in the navbar.
    expect(find.text('Barbershop Manager'), findsOneWidget);
  });

  testWidgets('desktop: brand + toggle in sidebar header; name only while open; no hover labels on them', (
    tester,
  ) async {
    setScreen(tester, const Size(1400, 900));
    await tester.pumpWidget(shell(FakeAuthController(AuthSignedIn(managerUser()))));
    await tester.pumpAndSettle();

    final header = find.descendant(of: find.byType(AppSidebar), matching: find.byKey(const Key('salon-name')));
    expect(header, findsOneWidget);
    expect(find.descendant(of: find.byType(AppSidebar), matching: find.text('Barbershop Manager')), findsOneWidget);
    // Collapse button sits to the right of the logo.
    final toggle = find.byKey(const Key('sidebar-toggle'));
    expect(tester.getCenter(toggle).dx, greaterThan(tester.getCenter(header).dx));
    // Settings is reached from the profile box, not the sidebar.
    expect(find.descendant(of: find.byType(AppSidebar), matching: find.text('Settings')), findsNothing);
    // Hover labels are switched off for the toggle and app name (AppHoverLabels).
    expect(find.byTooltip('Collapse menu'), findsNothing);
    expect(find.byTooltip('Barbershop Manager'), findsNothing);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text('Barbershop Manager'), findsNothing); // scissors icon only
    expect(header, findsOneWidget);
    expect(tester.getCenter(toggle).dx, greaterThan(tester.getCenter(header).dx));
    expect(find.byTooltip('Expand menu'), findsNothing);
  });

  testWidgets('desktop: sidebar starts expanded and the toggle collapses it', (tester) async {
    setScreen(tester, const Size(1400, 900));
    final store = InMemorySecureStore();
    await tester.pumpWidget(shell(FakeAuthController(AuthSignedIn(staffUser())), store: store));
    await tester.pumpAndSettle();

    final sidebar = find.byType(AppSidebar);
    expect(tester.getSize(sidebar).width, 248);
    expect(find.text('Customers'), findsOneWidget);

    await tester.tap(find.byKey(const Key('sidebar-toggle')));
    await tester.pumpAndSettle();
    expect(tester.getSize(sidebar).width, 80);
    expect(find.text('Customers'), findsNothing); // label hidden …
    expect(find.byTooltip('Customers'), findsOneWidget); // … shown on hover instead
    expect(await store.read(SecureStoreKeys.sidebarCollapsed), 'true'); // remembered

    await tester.tap(find.byKey(const Key('sidebar-toggle')));
    await tester.pumpAndSettle();
    expect(tester.getSize(sidebar).width, 248);
  });

  testWidgets('tablet: sidebar starts collapsed', (tester) async {
    setScreen(tester, const Size(900, 1000));
    await tester.pumpWidget(shell(FakeAuthController(AuthSignedIn(staffUser()))));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(AppSidebar)).width, 80);
  });

  testWidgets('profile menu: staff sees profile, theme and logout but not settings', (tester) async {
    setScreen(tester, const Size(1400, 900));
    final controller = FakeAuthController(AuthSignedIn(staffUser()));
    await tester.pumpWidget(shell(controller));
    await tester.pumpAndSettle();

    expect(find.text('Asha Rao'), findsOneWidget);
    // Profile box sits at the right edge of the navbar.
    expect(tester.getTopRight(find.byKey(const Key('profile-button'))).dx, greaterThan(1400 - 40));
    await tester.tap(find.byKey(const Key('profile-button')));
    await tester.pumpAndSettle();

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Dark mode'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
    expect(find.widgetWithText(MenuItemButton, 'Settings'), findsNothing);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(controller.logouts, 1);
  });

  testWidgets('profile menu: manager also sees settings', (tester) async {
    setScreen(tester, const Size(1400, 900));
    await tester.pumpWidget(shell(FakeAuthController(AuthSignedIn(managerUser()))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-button')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(MenuItemButton, 'Settings'), findsOneWidget);
  });

  testWidgets('dark mode toggle switches the theme and is remembered', (tester) async {
    setScreen(tester, const Size(1400, 900));
    final store = InMemorySecureStore();
    await tester.pumpWidget(shell(FakeAuthController(AuthSignedIn(staffUser())), store: store));
    await tester.pumpAndSettle();

    BuildContext ctx() => tester.element(find.byType(AppSidebar));
    expect(Theme.of(ctx()).brightness, Brightness.light);

    await tester.tap(find.byKey(const Key('profile-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('theme-toggle')));
    await tester.pumpAndSettle();

    expect(Theme.of(ctx()).brightness, Brightness.dark);
    expect(AppColors.of(ctx()).primaryButton, const Color(0xFFD6B779));
    expect(await store.read(SecureStoreKeys.themeMode), 'dark');
  });

  testWidgets('clicking the salon name returns to the dashboard; sidebar items navigate', (tester) async {
    setScreen(tester, const Size(1400, 900));
    final router = GoRouter(
      initialLocation: '/customers',
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(location: state.matchedLocation, child: child),
          routes: [
            for (final path in ['/dashboard', '/customers', '/appointments'])
              GoRoute(path: path, builder: (_, _) => Text('page $path')),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(() => FakeAuthController(AuthSignedIn(staffUser()))),
          secureStoreProvider.overrideWithValue(InMemorySecureStore()),
        ],
        child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('page /customers'), findsOneWidget);

    await tester.tap(find.byKey(const Key('salon-name')));
    await tester.pumpAndSettle();
    expect(find.text('page /dashboard'), findsOneWidget);

    // Collapsed icons still navigate on click.
    await tester.tap(find.byKey(const Key('sidebar-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Appointments'));
    await tester.pumpAndSettle();
    expect(find.text('page /appointments'), findsOneWidget);
  });

  testWidgets('saved preferences are restored on start', (tester) async {
    setScreen(tester, const Size(1400, 900));
    final store = InMemorySecureStore({SecureStoreKeys.themeMode: 'dark', SecureStoreKeys.sidebarCollapsed: 'true'});
    await tester.pumpWidget(shell(FakeAuthController(AuthSignedIn(staffUser())), store: store));
    await tester.pumpAndSettle();

    expect(Theme.of(tester.element(find.byType(AppSidebar))).brightness, Brightness.dark);
    expect(tester.getSize(find.byType(AppSidebar)).width, 80);
  });
}
