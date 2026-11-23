import 'package:barbershop_app/config/env/app_env.dart';
import 'package:barbershop_app/config/theme/app_colors.dart';
import 'package:barbershop_app/config/theme/app_typography.dart';
import 'package:barbershop_app/core/auth/auth_models.dart';
import 'package:barbershop_app/core/router/app_destinations.dart';
import 'package:barbershop_app/core/router/app_shell.dart';
import 'package:barbershop_app/core/router/app_sidebar.dart';
import 'package:barbershop_app/core/server/server_address.dart';
import 'package:barbershop_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void setScreen(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget shell(CurrentUser user) =>
    harness(FakeAuthController(AuthSignedIn(user)), const AppShell(location: '/dashboard', child: SizedBox()));

void main() {
  group('displayServerAddress', () {
    test('shows host and port only', () {
      expect(displayServerAddress('http://192.168.1.10:8080/api/v1'), '192.168.1.10:8080');
      expect(displayServerAddress('https://salon.example.com/api/v1'), 'salon.example.com');
    });

    test('is null when no server is set', () {
      expect(displayServerAddress(''), isNull);
    });
  });

  test('headings use the bundled Fraunces font with an explicit weight axis', () {
    final title = AppTypography.textTheme.displaySmall!;
    expect(title.fontFamily, 'Fraunces');
    expect(title.fontWeight, FontWeight.w600);
    expect(title.fontVariations, contains(const FontVariation('wght', 600)));
    // Body text stays on the platform font.
    expect(AppTypography.textTheme.bodyMedium!.fontFamily, isNull);
  });

  test('server setup is switched off: the app always has a server and no Change server option', () {
    final env = AppEnv.fromDefines();
    expect(AppEnv.serverSetupEnabled, isFalse);
    expect(env.allowServerOverride, isFalse);
    expect(env.defaultApiBaseUrl, 'http://localhost:8080/api/v1');
  });

  test('greeting follows the time of day', () {
    expect(greetingFor(DateTime(2026, 11, 18, 9)), 'Good morning');
    expect(greetingFor(DateTime(2026, 11, 18, 12, 40)), 'Good afternoon');
    expect(greetingFor(DateTime(2026, 11, 18, 19)), 'Good evening');
  });

  test('each group lists its sections next to each other', () {
    final seen = <AppNavGroup>[];
    for (final d in AppDestinations.all) {
      if (seen.isEmpty || seen.last != d.group) {
        expect(seen, isNot(contains(d.group)), reason: '${d.label} splits group ${d.group.label}');
        seen.add(d.group);
      }
    }
  });

  testWidgets('desktop: dark side menu with group labels', (tester) async {
    setScreen(tester, const Size(1400, 900));
    await tester.pumpWidget(shell(staffUser()));
    await tester.pumpAndSettle();

    final sidebar = find.byType(AppSidebar);
    final container = tester.widget<AnimatedContainer>(
      find.descendant(of: sidebar, matching: find.byType(AnimatedContainer)).first,
    );
    expect((container.decoration as BoxDecoration?)?.color, AppColors.light.sidebarBackground);
    expect(find.descendant(of: sidebar, matching: find.text('FRONT DESK')), findsOneWidget);
    // Staff has no Business or Admin sections, so those labels are absent.
    expect(find.descendant(of: sidebar, matching: find.text('ADMIN')), findsNothing);
  });

  testWidgets('New bill button shows for people who may create bills', (tester) async {
    setScreen(tester, const Size(1400, 900));
    await tester.pumpWidget(shell(staffUser())); // has billing.create
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('navbar-new-bill')), findsOneWidget);
  });

  testWidgets('New bill button is hidden without billing.create', (tester) async {
    setScreen(tester, const Size(1400, 900));
    await tester.pumpWidget(shell(managerUser())); // the fake manager lacks billing.create
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('navbar-new-bill')), findsNothing);
  });

  testWidgets('phone: no New bill button in the top bar (Billing is in the bottom bar)', (tester) async {
    setScreen(tester, const Size(375, 812));
    await tester.pumpWidget(shell(staffUser()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('navbar-new-bill')), findsNothing);
  });
}
