import 'package:barbershop_app/core/auth/auth_models.dart';
import 'package:barbershop_app/core/permissions.dart';
import 'package:barbershop_app/core/router/app_destinations.dart';
import 'package:barbershop_app/core/router/app_router.dart';
import 'package:barbershop_app/core/server/server_address.dart';
import 'package:flutter_test/flutter_test.dart';

CurrentUser user(Set<String> permissions) =>
    CurrentUser(id: 1, fullName: 'Test', branchId: 1, roleId: 1, permissions: permissions);

void main() {
  group('resolveRedirect', () {
    test('sends everything to the splash while restoring', () {
      expect(resolveRedirect(const AuthLoading(), '/customers'), AppRoutes.splash);
      expect(resolveRedirect(const AuthLoading(), AppRoutes.splash), isNull);
    });

    test('forces server setup when no server is configured', () {
      expect(resolveRedirect(const AuthNeedsServer(), AppRoutes.login), AppRoutes.server);
    });

    test('forces login when signed out', () {
      expect(resolveRedirect(const AuthSignedOut(), '/dashboard'), AppRoutes.login);
      expect(resolveRedirect(const AuthSignedOut(), AppRoutes.login), isNull);
    });

    test('moves a signed-in user off public pages', () {
      expect(resolveRedirect(AuthSignedIn(user({})), AppRoutes.login), '/dashboard');
    });

    test('blocks pages the user has no permission for, including sub-pages', () {
      final staff = AuthSignedIn(user({Permissions.customersView}));
      expect(resolveRedirect(staff, '/customers'), isNull);
      expect(resolveRedirect(staff, '/customers/42'), isNull);
      expect(resolveRedirect(staff, '/settings'), '/dashboard');
      expect(resolveRedirect(staff, '/inventory/3'), '/dashboard');
    });
  });

  group('AppDestinations', () {
    test('a staff member sees only permitted sections', () {
      final staff = user({Permissions.appointmentsView, Permissions.billingCreate, Permissions.earningsViewOwn});
      final labels = AppDestinations.menuFor(staff).map((d) => d.label);
      expect(labels, ['Dashboard', 'Appointments', 'Billing', 'My earnings']);
    });

    test('Settings is never in the menu but stays reachable for managers', () {
      final manager = user({Permissions.settingsManage});
      expect(AppDestinations.menuFor(manager).map((d) => d.label), isNot(contains('Settings')));
      expect(resolveRedirect(AuthSignedIn(manager), '/settings'), isNull);
      expect(resolveRedirect(AuthSignedIn(user({})), '/settings'), '/dashboard');
    });

    test('maps nested locations to their section', () {
      expect(AppDestinations.forLocation('/staff/5/compensation'), AppDestinations.staff);
      expect(AppDestinations.forLocation('/staffing'), isNull);
    });
  });

  group('normalizeServerAddress', () {
    test('accepts bare host:port and adds scheme and API path', () {
      expect(normalizeServerAddress('192.168.1.10:8080'), 'http://192.168.1.10:8080/api/v1');
    });

    test('keeps https and trims trailing slashes', () {
      expect(normalizeServerAddress(' https://salon.example.com/ '), 'https://salon.example.com/api/v1');
    });

    test('does not duplicate the API path', () {
      expect(normalizeServerAddress('http://pc:8080/api/v1'), 'http://pc:8080/api/v1');
    });

    test('rejects nonsense', () {
      expect(normalizeServerAddress(''), isNull);
      expect(normalizeServerAddress('ftp://pc'), isNull);
    });
  });
}
