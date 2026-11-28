import 'package:barbershop_app/config/theme/app_theme.dart';
import 'package:barbershop_app/core/auth/auth_controller.dart';
import 'package:barbershop_app/core/auth/auth_models.dart';
import 'package:barbershop_app/core/permissions.dart';
import 'package:barbershop_app/core/providers.dart';
import 'package:barbershop_app/core/storage/secure_store.dart';
import 'package:barbershop_app/features/compensation/application/compensation_providers.dart';
import 'package:barbershop_app/features/compensation/data/compensation_api.dart';
import 'package:barbershop_app/features/compensation/domain/pay.dart';
import 'package:barbershop_app/features/compensation/presentation/pay_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/fakes.dart';

PayItem service(int id, String name, {String? rate}) => PayItem(
  type: PayItemType.service,
  itemId: id,
  name: name,
  price: '200.00',
  ratePct: rate,
  source: rate == null ? RateSource.salonDefault : RateSource.specific,
);

PayItem product(int id, String name, {String? rate}) => PayItem(
  type: PayItemType.product,
  itemId: id,
  name: name,
  detail: 'Brand',
  price: '450.00',
  ratePct: rate,
  source: rate == null ? RateSource.salonDefault : RateSource.specific,
);

class FakeCompensationApi implements CompensationApi {
  String defaultPct = '10.00';
  final calls = <String>[];
  String? savedSalary;
  List<RateChange>? savedRates;

  final pays = <int, StaffPay>{
    1: StaffPay(
      staffId: 1,
      fullName: 'Rahul Verma',
      roleName: 'Barber',
      performsServices: true,
      salonDefaultPct: '10.00',
      services: [
        service(1, 'Haircut', rate: '40.00'),
        service(2, 'Beard Trim'),
      ],
      products: [product(3, 'Hair Wax')],
    ),
    2: const StaffPay(
      staffId: 2,
      fullName: 'Asha Rao',
      roleName: 'Stylist',
      performsServices: true,
      monthlySalary: '18000.00',
      salonDefaultPct: '10.00',
      services: [],
      products: [],
    ),
  };

  @override
  Future<String> salonDefault() async => defaultPct;

  @override
  Future<String> setSalonDefault(String pct) async {
    calls.add('default:$pct');
    return defaultPct = pct;
  }

  @override
  Future<List<PaySummary>> summaries() async => [
    for (final p in pays.values)
      PaySummary(
        staffId: p.staffId,
        fullName: p.fullName,
        roleName: p.roleName,
        performsServices: p.performsServices,
        monthlySalary: p.monthlySalary,
        specificRates: [...p.services, ...p.products].where((i) => i.ratePct != null).length,
      ),
  ];

  @override
  Future<StaffPay> staffPay(int staffId) async {
    calls.add('pay:$staffId');
    return pays[staffId]!;
  }

  @override
  Future<StaffPay> save(int staffId, {required String? monthlySalary, required List<RateChange> rates}) async {
    calls.add('save:$staffId');
    savedSalary = monthlySalary;
    savedRates = rates;
    return pays[staffId]!;
  }
}

final owner = CurrentUser(
  id: 1,
  fullName: 'Owner',
  branchId: 1,
  roleId: 1,
  permissions: {Permissions.compensationView, Permissions.compensationManage},
);
final viewer = CurrentUser(
  id: 2,
  fullName: 'Desk',
  branchId: 1,
  roleId: 2,
  permissions: {Permissions.compensationView},
);

Future<void> pumpPay(WidgetTester tester, FakeCompensationApi api, {CurrentUser? user, Size? size}) async {
  tester.view.physicalSize = size ?? const Size(1400, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/staff/pay',
    routes: [GoRoute(path: '/staff/pay', builder: (_, _) => const PaySetupScreen())],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(() => FakeAuthController(AuthSignedIn(user ?? owner))),
        secureStoreProvider.overrideWithValue(InMemorySecureStore()),
        compensationApiProvider.overrideWithValue(api),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

String fieldText(WidgetTester tester, String key) => tester
    .widget<EditableText>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(EditableText)))
    .controller
    .text;

void main() {
  testWidgets('lists employees and opens the first one with own rates and defaults', (tester) async {
    await pumpPay(tester, FakeCompensationApi());
    expect(find.text('Rahul Verma'), findsWidgets);
    expect(find.textContaining('Salary ₹18,000.00'), findsOneWidget);
    expect(fieldText(tester, 'rate-SERVICE:1'), '40');
    expect(fieldText(tester, 'rate-SERVICE:2'), '');
    expect(find.byKey(const Key('rate-note-SERVICE:1')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('rate-note-SERVICE:1'))).data, 'Own rate');
    expect(tester.widget<Text>(find.byKey(const Key('rate-note-SERVICE:2'))).data, 'Default 10%');
    expect(fieldText(tester, 'salon-default'), '10');
  });

  testWidgets('sends the salary and only the changed rates', (tester) async {
    final api = FakeCompensationApi();
    await pumpPay(tester, api);
    await tester.enterText(find.byKey(const Key('rate-SERVICE:1')), ''); // remove own rate
    await tester.enterText(find.byKey(const Key('rate-PRODUCT:3')), '5');
    await tester.pump();
    await tester.tap(find.byKey(const Key('pay-save')));
    await tester.pumpAndSettle();

    expect(api.calls, contains('save:1'));
    expect(api.savedSalary, isNull);
    expect(api.savedRates!.map((r) => '${r.type.api}:${r.itemId}=${r.ratePct}'), ['SERVICE:1=null', 'PRODUCT:3=5']);
  });

  testWidgets('typing a salary switches blank rates to "No commission"', (tester) async {
    await pumpPay(tester, FakeCompensationApi());
    await tester.enterText(find.byKey(const Key('pay-salary')), '15000');
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('rate-note-SERVICE:2'))).data, 'No commission');
    expect(find.text('Salaried'), findsOneWidget);
  });

  testWidgets('rejects a rate above 100%', (tester) async {
    final api = FakeCompensationApi();
    await pumpPay(tester, api);
    await tester.enterText(find.byKey(const Key('rate-SERVICE:2')), '150');
    await tester.pump();
    await tester.tap(find.byKey(const Key('pay-save')));
    await tester.pumpAndSettle();
    expect(api.calls, isNot(contains('save:1')));
  });

  testWidgets('selecting another employee loads their pay', (tester) async {
    final api = FakeCompensationApi();
    await pumpPay(tester, api);
    await tester.tap(find.byKey(const Key('pay-employee-2')));
    await tester.pumpAndSettle();
    expect(api.calls, contains('pay:2'));
    expect(fieldText(tester, 'pay-salary'), '18000');
    expect(find.textContaining('No active services yet'), findsOneWidget);
  });

  testWidgets('saves the salon default', (tester) async {
    final api = FakeCompensationApi();
    await pumpPay(tester, api);
    await tester.enterText(find.byKey(const Key('salon-default')), '12.5');
    await tester.tap(find.byKey(const Key('salon-default-save')));
    await tester.pumpAndSettle();
    expect(api.calls, contains('default:12.5'));
  });

  testWidgets('is read-only without compensation.manage', (tester) async {
    await pumpPay(tester, FakeCompensationApi(), user: viewer);
    expect(find.byKey(const Key('pay-save')), findsNothing);
    expect(find.byKey(const Key('salon-default-save')), findsNothing);
    expect(find.text('View only'), findsWidgets);
  });

  testWidgets('phone width uses an employee picker', (tester) async {
    await pumpPay(tester, FakeCompensationApi(), size: const Size(400, 1600));
    expect(find.byKey(const Key('pay-employee-picker')), findsOneWidget);
    expect(find.byKey(const Key('pay-employee-1')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
