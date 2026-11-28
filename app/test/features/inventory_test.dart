import 'package:barbershop_app/config/theme/app_theme.dart';
import 'package:barbershop_app/core/auth/auth_controller.dart';
import 'package:barbershop_app/core/auth/auth_models.dart';
import 'package:barbershop_app/core/network/api_exception.dart';
import 'package:barbershop_app/core/permissions.dart';
import 'package:barbershop_app/core/providers.dart';
import 'package:barbershop_app/core/storage/secure_store.dart';
import 'package:barbershop_app/core/utils/money_format.dart';
import 'package:barbershop_app/features/inventory/application/inventory_providers.dart';
import 'package:barbershop_app/features/inventory/data/inventory_api.dart';
import 'package:barbershop_app/features/inventory/domain/product.dart';
import 'package:barbershop_app/features/inventory/presentation/inventory_list_screen.dart';
import 'package:barbershop_app/features/inventory/presentation/product_detail_screen.dart';
import 'package:barbershop_app/features/inventory/presentation/product_new_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/fakes.dart';

Product product(int id, String name, {int stock = 10, int alert = 2, bool active = true, int version = 1}) => Product(
  id: id,
  name: name,
  brand: 'Beardo',
  category: 'Shampoo',
  mrp: '2000.00',
  defaultDiscountPct: '10.00',
  sellingPrice: '1800.00',
  lastPurchasePrice: '1600.00',
  stockQuantity: stock,
  lowStockThreshold: alert,
  isLowStock: stock <= alert,
  isActive: active,
  version: version,
);

class FakeInventoryApi implements InventoryApi {
  FakeInventoryApi(this.items);

  final List<Product> items;
  final calls = <String>[];
  ProductDraft? lastDraft;
  PurchaseDraft? lastPurchase;

  @override
  Future<({List<Product> items, int total})> list({
    String? search,
    String? category,
    StatusFilter status = StatusFilter.active,
    bool lowStockOnly = false,
    int offset = 0,
  }) async {
    calls.add('list:${search ?? ''}:${category ?? ''}:${status.name}:$lowStockOnly');
    final found = items
        .where((p) => status == StatusFilter.all || p.isActive == (status == StatusFilter.active))
        .where((p) => !lowStockOnly || p.isLowStock)
        .toList();
    return (items: found, total: found.length);
  }

  @override
  Future<Product> get(int id) async => items.firstWhere((p) => p.id == id);

  @override
  Future<({List<String> categories, List<String> brands})> suggestions() async =>
      (categories: const ['Shampoo', 'Wax'], brands: const ['Beardo']);

  @override
  Future<Product> create(ProductDraft draft, {PurchaseDraft? openingStock}) async {
    calls.add('create');
    lastDraft = draft;
    lastPurchase = openingStock;
    final p = product(77, draft.name, stock: openingStock?.quantity ?? 0);
    items.add(p);
    return p;
  }

  @override
  Future<Product> update(int id, int version, ProductDraft draft) async {
    calls.add('update:$version');
    lastDraft = draft;
    return items.firstWhere((p) => p.id == id);
  }

  @override
  Future<Product> setActive(int id, bool active) async {
    calls.add('setActive:$active');
    return items.firstWhere((p) => p.id == id);
  }

  @override
  Future<Product> receive(int id, PurchaseDraft purchase) async {
    calls.add('receive');
    lastPurchase = purchase;
    return items.firstWhere((p) => p.id == id);
  }

  /// When set, the next adjustment is refused with this error.
  ApiException? adjustError;

  @override
  Future<Product> adjust(
    int id, {
    required bool stockIn,
    required int quantity,
    required AdjustmentReason reason,
    String? note,
  }) async {
    calls.add('adjust:${stockIn ? 'in' : 'out'}:$quantity:${reason.key}');
    final error = adjustError;
    if (error != null) {
      adjustError = null;
      throw error;
    }
    return items.firstWhere((p) => p.id == id);
  }

  @override
  Future<({List<StockMovement> items, String? nextCursor})> movements(int id, {String? cursor, int limit = 30}) async =>
      (
        items: [
          StockMovement(
            id: 1,
            type: MovementType.purchase,
            quantityDelta: 12,
            unitCost: '1600.00',
            supplierName: 'Sharma Traders',
            note: 'Opening stock',
            createdBy: 'Salon Owner',
            createdAt: DateTime(2026, 11, 24, 10),
          ),
          StockMovement(
            id: 2,
            type: MovementType.adjustment,
            quantityDelta: -2,
            reason: 'DAMAGED',
            createdBy: 'Salon Owner',
            createdAt: DateTime(2026, 11, 24, 11),
          ),
        ],
        nextCursor: null,
      );
}

final manager = CurrentUser(
  id: 1,
  fullName: 'Owner',
  branchId: 1,
  roleId: 1,
  permissions: {Permissions.inventoryView, Permissions.inventoryManage},
);
final viewer = CurrentUser(id: 2, fullName: 'Asha', branchId: 1, roleId: 2, permissions: {Permissions.inventoryView});

Future<GoRouter> pumpInventory(
  WidgetTester tester,
  FakeInventoryApi api, {
  String at = '/inventory',
  CurrentUser? user,
}) async {
  tester.view.physicalSize = const Size(1300, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: at,
    routes: [
      GoRoute(
        path: '/inventory',
        builder: (_, _) => const InventoryListScreen(),
        routes: [
          GoRoute(path: 'new', builder: (_, _) => const ProductNewScreen()),
          GoRoute(
            path: ':id',
            builder: (_, s) => ProductDetailScreen(id: int.parse(s.pathParameters['id']!)),
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
        inventoryApiProvider.overrideWithValue(api),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  test('money is shown in rupees with Indian grouping', () {
    expect(formatMoney('1800.00'), '₹1,800.00');
    expect(formatMoney('125000.50'), '₹1,25,000.50');
    expect(formatMoney(null), '—');
    expect(formatPercent('10.00'), '10%');
    expect(formatPercent('12.50'), '12.5%');
  });

  group('inventory list', () {
    testWidgets('shows stock and prices, flags low stock and filters', (tester) async {
      final api = FakeInventoryApi([product(1, 'Argan Oil', stock: 1), product(2, 'Beard Wax', stock: 20)]);
      await pumpInventory(tester, api);

      expect(find.text('Argan Oil'), findsOneWidget);
      expect(find.text('Low stock'), findsOneWidget);
      expect(find.text('₹1,800.00'), findsNWidgets(2));
      expect(find.byKey(const Key('add-product')), findsOneWidget);

      await tester.tap(find.byKey(const Key('low-stock-filter')));
      await tester.pumpAndSettle();
      expect(api.calls.last, endsWith(':true'));
      expect(find.text('Beard Wax'), findsNothing);
    });

    testWidgets('view-only users cannot add', (tester) async {
      await pumpInventory(tester, FakeInventoryApi([product(1, 'Argan Oil')]), user: viewer);
      expect(find.byKey(const Key('add-product')), findsNothing);
    });
  });

  group('add product', () {
    testWidgets('shows the selling price while typing and sends opening stock', (tester) async {
      final api = FakeInventoryApi([]);
      final router = await pumpInventory(tester, api, at: '/inventory/new');

      await tester.enterText(find.byKey(const Key('product-name')), 'Anti-dandruff Shampoo');
      await tester.enterText(find.byKey(const Key('product-mrp')), '2000');
      await tester.enterText(find.byKey(const Key('product-discount')), '10');
      await tester.pump();
      expect(find.text('Selling price to customers: ₹1,800.00'), findsOneWidget);

      // Existing categories are offered as one-tap chips.
      await tester.tap(find.widgetWithText(ActionChip, 'Shampoo'));
      await tester.enterText(find.byKey(const Key('opening-qty')), '12');
      await tester.enterText(find.byKey(const Key('opening-cost')), '1600');
      await tester.ensureVisible(find.byKey(const Key('product-submit')));
      await tester.tap(find.byKey(const Key('product-submit')));
      await tester.pumpAndSettle();

      expect(api.lastDraft!.name, 'Anti-dandruff Shampoo');
      expect(api.lastDraft!.category, 'Shampoo');
      expect(api.lastDraft!.mrp, '2000');
      expect(api.lastDraft!.defaultDiscountPct, '10');
      expect(api.lastPurchase!.quantity, 12);
      expect(api.lastPurchase!.unitCost, '1600');
      expect(router.routeInformationProvider.value.uri.path, '/inventory/77');
    });

    testWidgets('checks fields before sending', (tester) async {
      final api = FakeInventoryApi([]);
      await pumpInventory(tester, api, at: '/inventory/new');

      await tester.enterText(find.byKey(const Key('product-discount')), '150');
      await tester.enterText(find.byKey(const Key('opening-qty')), '5'); // quantity without a price
      await tester.ensureVisible(find.byKey(const Key('product-submit')));
      await tester.tap(find.byKey(const Key('product-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Enter a product name'), findsOneWidget);
      expect(find.text('Enter an amount'), findsNWidgets(2)); // MRP and buying price
      expect(find.text('Enter 0 to 100'), findsOneWidget);
      expect(api.calls, isNot(contains('create')));
    });

    testWidgets('without opening stock sends none', (tester) async {
      final api = FakeInventoryApi([]);
      await pumpInventory(tester, api, at: '/inventory/new');
      await tester.enterText(find.byKey(const Key('product-name')), 'Hair Gel');
      await tester.enterText(find.byKey(const Key('product-mrp')), '150');
      await tester.ensureVisible(find.byKey(const Key('product-submit')));
      await tester.tap(find.byKey(const Key('product-submit')));
      await tester.pumpAndSettle();
      expect(api.calls, contains('create'));
      expect(api.lastPurchase, isNull);
    });
  });

  group('product page', () {
    testWidgets('shows stock, prices and readable history', (tester) async {
      await pumpInventory(tester, FakeInventoryApi([product(5, 'Argan Oil', stock: 10)]), at: '/inventory/5');

      expect(find.byKey(const Key('stock-quantity')), findsOneWidget);
      expect(find.text('₹1,600.00'), findsOneWidget); // last buying price
      expect(find.text('+12'), findsOneWidget);
      expect(find.textContaining('Delivery at ₹1,600.00 each · Sharma Traders · Opening stock'), findsOneWidget);
      expect(find.text('-2'), findsOneWidget);
      expect(find.text('Adjustment · Damaged'), findsOneWidget);
    });

    testWidgets('receives a delivery', (tester) async {
      final api = FakeInventoryApi([product(5, 'Argan Oil')]);
      await pumpInventory(tester, api, at: '/inventory/5');

      await tester.tap(find.byKey(const Key('receive-stock')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('receive-qty')), '6');
      await tester.enterText(find.byKey(const Key('receive-cost')), '1550.50');
      await tester.tap(find.byKey(const Key('receive-save')));
      await tester.pumpAndSettle();

      expect(api.lastPurchase!.quantity, 6);
      expect(api.lastPurchase!.unitCost, '1550.50');
      expect(find.text('Stock added'), findsOneWidget);
    });

    testWidgets('adjusting needs a reason', (tester) async {
      final api = FakeInventoryApi([product(5, 'Argan Oil')]);
      await pumpInventory(tester, api, at: '/inventory/5');

      await tester.tap(find.byKey(const Key('adjust-stock')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('adjust-qty')), '2');
      await tester.tap(find.byKey(const Key('adjust-save')));
      await tester.pumpAndSettle();
      expect(find.text('Choose a reason'), findsOneWidget);

      await tester.tap(find.byKey(const Key('adjust-reason')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Used in the salon').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('adjust-save')));
      await tester.pumpAndSettle();
      expect(api.calls, contains('adjust:out:2:USED_IN_SALON'));
    });

    testWidgets('shows a refused adjustment inside the dialog', (tester) async {
      final api = FakeInventoryApi([product(5, 'Argan Oil', stock: 12)])
        ..adjustError = const ApiException(
          code: 'STOCK_INSUFFICIENT',
          message: "Only 12 in stock, so 20 can't be taken out.",
          statusCode: 422,
        );
      await pumpInventory(tester, api, at: '/inventory/5');

      await tester.tap(find.byKey(const Key('adjust-stock')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('adjust-qty')), '20');
      await tester.tap(find.byKey(const Key('adjust-reason')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Damaged').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('adjust-save')));
      await tester.pumpAndSettle();

      // Visible in the still-open dialog, not in a snackbar behind it.
      final error = find.descendant(of: find.byType(AlertDialog), matching: find.byKey(const Key('dialog-error')));
      expect(error, findsOneWidget);
      expect(find.text("Only 12 in stock, so 20 can't be taken out."), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('saves edits with the loaded version', (tester) async {
      final api = FakeInventoryApi([product(5, 'Argan Oil', version: 4)]);
      await pumpInventory(tester, api, at: '/inventory/5');
      await tester.enterText(find.byKey(const Key('product-mrp')), '2100');
      await tester.ensureVisible(find.byKey(const Key('product-submit')));
      await tester.tap(find.byKey(const Key('product-submit')));
      await tester.pumpAndSettle();
      expect(api.calls, contains('update:4'));
      expect(api.lastDraft!.mrp, '2100');
    });

    testWidgets('is read-only without inventory.manage', (tester) async {
      await pumpInventory(tester, FakeInventoryApi([product(5, 'Argan Oil')]), at: '/inventory/5', user: viewer);
      expect(find.byKey(const Key('product-submit')), findsNothing);
      expect(find.byKey(const Key('receive-stock')), findsNothing);
      expect(find.byKey(const Key('toggle-product-active')), findsNothing);
    });
  });
}
