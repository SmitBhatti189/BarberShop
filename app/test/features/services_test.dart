import 'package:barbershop_app/config/theme/app_theme.dart';
import 'package:barbershop_app/core/auth/auth_controller.dart';
import 'package:barbershop_app/core/auth/auth_models.dart';
import 'package:barbershop_app/core/permissions.dart';
import 'package:barbershop_app/core/providers.dart';
import 'package:barbershop_app/core/storage/secure_store.dart';
import 'package:barbershop_app/features/services/application/services_providers.dart';
import 'package:barbershop_app/features/services/data/services_api.dart';
import 'package:barbershop_app/features/services/domain/salon_service.dart';
import 'package:barbershop_app/features/services/presentation/service_detail_screen.dart';
import 'package:barbershop_app/features/services/presentation/service_new_screen.dart';
import 'package:barbershop_app/features/services/presentation/services_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/fakes.dart';

SalonService svc(
  int id,
  String name, {
  String price = '200.00',
  int minutes = 30,
  bool active = true,
  int version = 1,
}) => SalonService(
  id: id,
  name: name,
  category: 'Hair',
  price: price,
  durationMinutes: minutes,
  isActive: active,
  version: version,
);

class FakeServicesApi implements ServicesApi {
  FakeServicesApi(this.items);

  final List<SalonService> items;
  final calls = <String>[];
  ServiceDraft? lastDraft;

  @override
  Future<({List<SalonService> items, int total})> list({
    String? search,
    String? category,
    StatusFilter status = StatusFilter.active,
    int offset = 0,
  }) async {
    calls.add('list:${search ?? ''}:${status.name}');
    final found = items
        .where((s) => status == StatusFilter.all || s.isActive == (status == StatusFilter.active))
        .where((s) => search == null || search.isEmpty || s.name.toLowerCase().contains(search.toLowerCase()))
        .toList();
    return (items: found, total: found.length);
  }

  @override
  Future<List<String>> categories() async => const ['Beard', 'Hair'];

  @override
  Future<SalonService> get(int id) async => items.firstWhere((s) => s.id == id);

  @override
  Future<SalonService> create(ServiceDraft draft) async {
    calls.add('create');
    lastDraft = draft;
    final s = svc(50, draft.name, price: draft.price, minutes: draft.durationMinutes);
    items.add(s);
    return s;
  }

  @override
  Future<SalonService> update(int id, int version, ServiceDraft draft) async {
    calls.add('update:$version');
    lastDraft = draft;
    return items.firstWhere((s) => s.id == id);
  }

  @override
  Future<SalonService> setActive(int id, bool active) async {
    calls.add('setActive:$active');
    return items.firstWhere((s) => s.id == id);
  }
}

final manager = CurrentUser(
  id: 1,
  fullName: 'Owner',
  branchId: 1,
  roleId: 1,
  permissions: {Permissions.servicesView, Permissions.servicesManage},
);
final staff = CurrentUser(id: 2, fullName: 'Asha', branchId: 1, roleId: 2, permissions: {Permissions.servicesView});

Future<GoRouter> pumpServices(
  WidgetTester tester,
  FakeServicesApi api, {
  String at = '/services',
  CurrentUser? user,
}) async {
  tester.view.physicalSize = const Size(1300, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: at,
    routes: [
      GoRoute(
        path: '/services',
        builder: (_, _) => const ServicesListScreen(),
        routes: [
          GoRoute(path: 'new', builder: (_, _) => const ServiceNewScreen()),
          GoRoute(
            path: ':id',
            builder: (_, s) => ServiceDetailScreen(id: int.parse(s.pathParameters['id']!)),
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
        servicesApiProvider.overrideWithValue(api),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  test('durations read naturally', () {
    expect(formatDuration(30), '30 min');
    expect(formatDuration(60), '1 h');
    expect(formatDuration(75), '1 h 15 min');
  });

  group('services list', () {
    testWidgets('shows price and duration; managers can add', (tester) async {
      await pumpServices(
        tester,
        FakeServicesApi([svc(1, 'Haircut'), svc(2, 'Beard Trim', price: '100.00', minutes: 15)]),
      );
      expect(find.text('Haircut'), findsOneWidget);
      expect(find.text('₹200.00'), findsOneWidget);
      expect(find.text('15 min'), findsOneWidget);
      expect(find.byKey(const Key('add-service')), findsOneWidget);
    });

    testWidgets('staff can view but not add', (tester) async {
      await pumpServices(tester, FakeServicesApi([svc(1, 'Haircut')]), user: staff);
      expect(find.text('Haircut'), findsOneWidget);
      expect(find.byKey(const Key('add-service')), findsNothing);
    });

    testWidgets('shows an empty state', (tester) async {
      await pumpServices(tester, FakeServicesApi([]));
      expect(find.textContaining('No services yet'), findsOneWidget);
    });
  });

  group('add service', () {
    testWidgets('checks fields before sending', (tester) async {
      final api = FakeServicesApi([]);
      await pumpServices(tester, api, at: '/services/new');
      await tester.tap(find.byKey(const Key('service-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Enter a service name'), findsOneWidget);
      expect(find.text('Enter an amount'), findsOneWidget);
      expect(find.text('Enter a number'), findsOneWidget);
      expect(api.calls, isNot(contains('create')));
    });

    testWidgets('quick duration and category chips fill the fields; saves and returns to the list', (tester) async {
      final api = FakeServicesApi([]);
      final router = await pumpServices(tester, api, at: '/services/new');

      await tester.enterText(find.byKey(const Key('service-name')), 'Haircut + Beard');
      await tester.enterText(find.byKey(const Key('service-price')), '250');
      await tester.tap(find.widgetWithText(ChoiceChip, '45 min'));
      await tester.tap(find.widgetWithText(ActionChip, 'Hair'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('service-submit')));
      await tester.pumpAndSettle();

      expect(api.lastDraft!.name, 'Haircut + Beard');
      expect(api.lastDraft!.price, '250');
      expect(api.lastDraft!.durationMinutes, 45);
      expect(api.lastDraft!.category, 'Hair');
      expect(router.routeInformationProvider.value.uri.path, '/services');
    });

    testWidgets('a new service appears in the list when coming back from Add', (tester) async {
      final api = FakeServicesApi([]);
      final router = await pumpServices(tester, api); // list first, so it stays mounted underneath
      expect(find.textContaining('No services yet'), findsOneWidget);

      router.go('/services/new');
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('service-name')), 'Beard Trim');
      await tester.enterText(find.byKey(const Key('service-price')), '100');
      await tester.tap(find.widgetWithText(ChoiceChip, '15 min'));
      await tester.tap(find.byKey(const Key('service-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Beard Trim'), findsOneWidget);
      expect(find.textContaining('No services yet'), findsNothing);
    });
  });

  group('service page', () {
    testWidgets('saves a new price with the loaded version', (tester) async {
      final api = FakeServicesApi([svc(3, 'Haircut', version: 5)]);
      await pumpServices(tester, api, at: '/services/3');
      await tester.enterText(find.byKey(const Key('service-price')), '220');
      await tester.tap(find.byKey(const Key('service-submit')));
      await tester.pumpAndSettle();
      expect(api.calls, contains('update:5'));
      expect(api.lastDraft!.price, '220');
      expect(find.text('Changes saved'), findsOneWidget);
    });

    testWidgets('deactivates after confirming', (tester) async {
      final api = FakeServicesApi([svc(3, 'Haircut')]);
      await pumpServices(tester, api, at: '/services/3');
      await tester.tap(find.byKey(const Key('toggle-service-active')));
      await tester.pumpAndSettle();
      expect(find.text('Stop offering Haircut?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Deactivate'));
      await tester.pumpAndSettle();
      expect(api.calls, contains('setActive:false'));
    });

    testWidgets('is read-only for staff', (tester) async {
      await pumpServices(tester, FakeServicesApi([svc(3, 'Haircut')]), at: '/services/3', user: staff);
      expect(find.byKey(const Key('service-submit')), findsNothing);
      expect(find.byKey(const Key('toggle-service-active')), findsNothing);
    });
  });
}
