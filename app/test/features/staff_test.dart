import 'package:barbershop_app/config/theme/app_theme.dart';
import 'package:barbershop_app/core/auth/auth_controller.dart';
import 'package:barbershop_app/core/auth/auth_models.dart';
import 'package:barbershop_app/core/network/api_exception.dart';
import 'package:barbershop_app/core/permissions.dart';
import 'package:barbershop_app/core/providers.dart';
import 'package:barbershop_app/core/storage/secure_store.dart';
import 'package:barbershop_app/features/staff/application/staff_providers.dart';
import 'package:barbershop_app/features/staff/data/staff_api.dart';
import 'package:barbershop_app/features/staff/domain/employee.dart';
import 'package:barbershop_app/features/staff/presentation/employee_detail_screen.dart';
import 'package:barbershop_app/features/staff/presentation/employee_new_screen.dart';
import 'package:barbershop_app/features/staff/presentation/staff_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/fakes.dart';

Employee emp(int id, String name, {bool active = true, String? username, int version = 1}) => Employee(
  id: id,
  fullName: name,
  roleId: 2,
  roleName: 'Staff',
  isActive: active,
  performsServices: true,
  version: version,
  mobile: '98765432${id.toString().padLeft(2, '0')}',
  username: username,
);

/// Records every call; answers from an in-memory list.
class FakeStaffApi implements StaffApi {
  FakeStaffApi(this.people);

  final List<Employee> people;
  final calls = <String>[];
  ApiException? nextError;
  EmployeeDraft? lastDraft;
  int? lastVersion;
  String? lastUsername;

  Never _fail() {
    final e = nextError!;
    nextError = null;
    throw e;
  }

  @override
  Future<EmployeePage> list({String? search, StatusFilter status = StatusFilter.active, int offset = 0}) async {
    calls.add('list:${search ?? ''}:${status.name}');
    final items = people
        .where((p) => status == StatusFilter.all || p.isActive == (status == StatusFilter.active))
        .where((p) => search == null || search.isEmpty || p.fullName.toLowerCase().contains(search.toLowerCase()))
        .toList();
    return EmployeePage(items: items, total: items.length);
  }

  @override
  Future<Employee> get(int id) async => people.firstWhere((p) => p.id == id);

  @override
  Future<Employee> create(EmployeeDraft draft, {String? username, String? password}) async {
    calls.add('create');
    lastDraft = draft;
    lastUsername = username;
    if (nextError != null) _fail();
    final e = emp(99, draft.fullName, username: username);
    people.add(e);
    return e;
  }

  @override
  Future<Employee> update(int id, int version, EmployeeDraft draft) async {
    calls.add('update');
    lastVersion = version;
    lastDraft = draft;
    if (nextError != null) _fail();
    final i = people.indexWhere((p) => p.id == id);
    return people[i] = emp(id, draft.fullName, version: version + 1);
  }

  @override
  Future<Employee> setActive(int id, bool active) async {
    calls.add('setActive:$active');
    if (nextError != null) _fail();
    final i = people.indexWhere((p) => p.id == id);
    return people[i] = emp(id, people[i].fullName, active: active, username: people[i].username);
  }

  @override
  Future<Employee> setLogin(int id, String username, String password) async {
    calls.add('setLogin:$username');
    return people.firstWhere((p) => p.id == id);
  }

  @override
  Future<Employee> removeLogin(int id) async {
    calls.add('removeLogin');
    return people.firstWhere((p) => p.id == id);
  }

  @override
  Future<List<RoleOption>> roles() async => const [
    RoleOption(id: 1, name: 'Manager'),
    RoleOption(id: 2, name: 'Staff'),
  ];
}

CurrentUser userWith(Set<String> permissions) =>
    CurrentUser(id: 1, fullName: 'Salon Owner', branchId: 1, roleId: 1, permissions: permissions);

final manager = userWith({Permissions.staffView, Permissions.staffManage});
final viewer = userWith({Permissions.staffView});

Future<GoRouter> pumpStaff(WidgetTester tester, FakeStaffApi api, {CurrentUser? user, String at = '/staff'}) async {
  tester.view.physicalSize = const Size(1300, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: at,
    routes: [
      GoRoute(
        path: '/staff',
        builder: (_, _) => const StaffListScreen(),
        routes: [
          GoRoute(path: 'new', builder: (_, _) => const EmployeeNewScreen()),
          GoRoute(
            path: ':id',
            builder: (_, s) => EmployeeDetailScreen(id: int.parse(s.pathParameters['id']!)),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(() => FakeAuthController(AuthSignedIn(user ?? manager))),
        secureStoreProvider.overrideWithValue(InMemorySecureStore()),
        staffApiProvider.overrideWithValue(api),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  group('employee list', () {
    testWidgets('lists active employees and offers "Add employee" to managers', (tester) async {
      final api = FakeStaffApi([emp(1, 'Asha Rao', username: 'asha'), emp(2, 'Vikram Singh', active: false)]);
      await pumpStaff(tester, api);

      expect(find.text('Asha Rao'), findsOneWidget);
      expect(find.text('Vikram Singh'), findsNothing); // inactive hidden by default
      expect(find.text('asha'), findsOneWidget); // sign-in column
      expect(find.byKey(const Key('add-employee')), findsOneWidget);

      await tester.tap(find.text('Inactive'));
      await tester.pumpAndSettle();
      expect(find.text('Vikram Singh'), findsOneWidget);
      expect(find.text('Asha Rao'), findsNothing);
    });

    testWidgets('searches after the user stops typing', (tester) async {
      final api = FakeStaffApi([emp(1, 'Asha Rao'), emp(2, 'Ravi Kumar')]);
      await pumpStaff(tester, api);

      await tester.enterText(find.byKey(const Key('employee-search')), 'ravi');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(api.calls.last, 'list:ravi:active');
      expect(find.text('Ravi Kumar'), findsOneWidget);
      expect(find.text('Asha Rao'), findsNothing);
    });

    testWidgets('view-only users cannot add', (tester) async {
      await pumpStaff(tester, FakeStaffApi([emp(1, 'Asha Rao')]), user: viewer);
      expect(find.byKey(const Key('add-employee')), findsNothing);
    });

    testWidgets('shows an empty state', (tester) async {
      await pumpStaff(tester, FakeStaffApi([]));
      expect(find.textContaining('No employees yet'), findsOneWidget);
    });
  });

  group('add employee', () {
    testWidgets('checks fields before sending', (tester) async {
      final api = FakeStaffApi([]);
      await pumpStaff(tester, api, at: '/staff/new');

      await tester.enterText(find.byKey(const Key('employee-mobile')), '12345');
      await tester.tap(find.byKey(const Key('employee-can-sign-in')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('employee-submit')));
      await tester.tap(find.byKey(const Key('employee-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Enter a name'), findsOneWidget);
      expect(find.text('Enter a 10-digit mobile number'), findsOneWidget);
      expect(find.text('Choose a role'), findsOneWidget);
      expect(find.text('At least 3 characters'), findsOneWidget);
      expect(find.text('At least 8 characters'), findsOneWidget);
      expect(api.calls, isNot(contains('create')));
    });

    testWidgets('sends the employee with a login and opens their page', (tester) async {
      final api = FakeStaffApi([]);
      final router = await pumpStaff(tester, api, at: '/staff/new');

      await tester.enterText(find.byKey(const Key('employee-name')), '  Meena Patel ');
      await tester.enterText(find.byKey(const Key('employee-mobile')), '+91 98765 43210');
      await tester.tap(find.byKey(const Key('employee-role')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Staff').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('employee-can-sign-in')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('employee-username')), 'meena');
      await tester.enterText(find.byKey(const Key('employee-password')), 'secret-pass-1');
      await tester.ensureVisible(find.byKey(const Key('employee-submit')));
      await tester.tap(find.byKey(const Key('employee-submit')));
      await tester.pumpAndSettle();

      expect(api.lastDraft!.fullName, 'Meena Patel');
      expect(api.lastDraft!.mobile, '+91 98765 43210'); // the server normalises it
      expect(api.lastDraft!.roleId, 2);
      expect(api.lastUsername, 'meena');
      expect(router.routeInformationProvider.value.uri.path, '/staff/99');
    });

    testWidgets('puts sign-in beside the details on wide screens and below them on phones', (tester) async {
      await pumpStaff(tester, FakeStaffApi([]), at: '/staff/new');
      final name = find.byKey(const Key('employee-name'));
      final signIn = find.byKey(const Key('employee-can-sign-in'));
      final submit = find.byKey(const Key('employee-submit'));
      expect(tester.getTopLeft(signIn).dx, greaterThan(tester.getTopRight(name).dx)); // right column
      expect(tester.getTopLeft(signIn).dy, lessThan(tester.getTopLeft(name).dy + 100)); // top-aligned
      expect(tester.getTopLeft(submit).dx, greaterThan(tester.getTopRight(name).dx)); // button with sign-in
      expect(tester.getBottomLeft(submit).dy, lessThan(1000)); // fits without scrolling

      tester.view.physicalSize = const Size(420, 900);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(signIn).dy, greaterThan(tester.getBottomLeft(name).dy)); // stacked
    });

    testWidgets('shows a duplicate-mobile error under the mobile field', (tester) async {
      final api = FakeStaffApi([])
        ..nextError = const ApiException(
          code: 'DUPLICATE',
          message: 'Another employee already has this mobile number',
          statusCode: 409,
          details: [
            {'field': 'mobile', 'message': 'Another employee already has this mobile number'},
          ],
        );
      await pumpStaff(tester, api, at: '/staff/new');

      await tester.enterText(find.byKey(const Key('employee-name')), 'Meena');
      await tester.enterText(find.byKey(const Key('employee-mobile')), '9876543210');
      await tester.tap(find.byKey(const Key('employee-role')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Staff').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('employee-submit')));
      await tester.tap(find.byKey(const Key('employee-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Another employee already has this mobile number'), findsOneWidget);
    });
  });

  group('employee page', () {
    testWidgets('saves edits with the version it loaded', (tester) async {
      final api = FakeStaffApi([emp(5, 'Asha Rao', version: 3)]);
      await pumpStaff(tester, api, at: '/staff/5');

      await tester.enterText(find.byKey(const Key('employee-name')), 'Asha R.');
      await tester.ensureVisible(find.byKey(const Key('employee-submit')));
      await tester.tap(find.byKey(const Key('employee-submit')));
      await tester.pumpAndSettle();

      expect(api.lastVersion, 3);
      expect(api.lastDraft!.fullName, 'Asha R.');
      expect(find.text('Changes saved'), findsOneWidget);
    });

    testWidgets('tells the user when someone else saved first', (tester) async {
      final api = FakeStaffApi([emp(5, 'Asha Rao')])
        ..nextError = const ApiException(
          code: 'STALE',
          message: 'Someone else changed this employee. Reload and try again.',
          statusCode: 409,
        );
      await pumpStaff(tester, api, at: '/staff/5');

      await tester.ensureVisible(find.byKey(const Key('employee-submit')));
      await tester.tap(find.byKey(const Key('employee-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Someone else changed this employee. Reload and try again.'), findsOneWidget);
    });

    testWidgets('deactivates only after confirming', (tester) async {
      final api = FakeStaffApi([emp(5, 'Asha Rao', username: 'asha')]);
      await pumpStaff(tester, api, at: '/staff/5');

      await tester.ensureVisible(find.byKey(const Key('toggle-active')));
      await tester.tap(find.byKey(const Key('toggle-active')));
      await tester.pumpAndSettle();
      expect(find.text('Deactivate Asha Rao?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(api.calls, isNot(contains('setActive:false')));

      await tester.tap(find.byKey(const Key('toggle-active')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Deactivate'));
      await tester.pumpAndSettle();
      expect(api.calls, contains('setActive:false'));
      expect(find.text('Reactivate employee'), findsOneWidget);
    });

    testWidgets('shows the server reason when an action is refused', (tester) async {
      final api = FakeStaffApi([emp(5, 'Owner', username: 'owner')])
        ..nextError = const ApiException(
          code: 'LAST_MANAGER',
          message: 'This is the only active manager who can sign in.',
          statusCode: 422,
        );
      await pumpStaff(tester, api, at: '/staff/5');

      await tester.ensureVisible(find.byKey(const Key('toggle-active')));
      await tester.tap(find.byKey(const Key('toggle-active')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Deactivate'));
      await tester.pumpAndSettle();
      expect(find.text('This is the only active manager who can sign in.'), findsOneWidget);
    });

    testWidgets('gives a login through the dialog', (tester) async {
      final api = FakeStaffApi([emp(5, 'Ravi')]);
      await pumpStaff(tester, api, at: '/staff/5');

      expect(find.textContaining('No login'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('set-login')));
      await tester.tap(find.byKey(const Key('set-login')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('login-username')), 'ravi');
      await tester.enterText(find.byKey(const Key('login-password')), 'secret-pass-1');
      await tester.tap(find.byKey(const Key('login-save')));
      await tester.pumpAndSettle();
      expect(api.calls, contains('setLogin:ravi'));
    });

    testWidgets('is read-only without staff.manage', (tester) async {
      await pumpStaff(tester, FakeStaffApi([emp(5, 'Asha Rao')]), user: viewer, at: '/staff/5');
      expect(find.byKey(const Key('employee-submit')), findsNothing);
      expect(find.byKey(const Key('toggle-active')), findsNothing);
      expect(find.byKey(const Key('set-login')), findsNothing);
    });
  });
}
