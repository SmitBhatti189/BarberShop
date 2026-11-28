import '../../../core/network/api_client.dart';
import '../domain/product.dart';

/// `/products` endpoints. Prices, stock checks and history are all decided by
/// the server; this class only moves data.
class InventoryApi {
  InventoryApi(this._api);

  final ApiClient _api;

  static const pageSize = 50;

  Future<({List<Product> items, int total})> list({
    String? search,
    String? category,
    StatusFilter status = StatusFilter.active,
    bool lowStockOnly = false,
    int offset = 0,
  }) async {
    final body = await _api.getEnvelope(
      '/products',
      query: {
        if (search != null && search.isNotEmpty) 'search': search,
        'category': ?category,
        'status': status.name,
        if (lowStockOnly) 'lowStock': 'true',
        'limit': pageSize,
        'offset': offset,
      },
    );
    return (
      items: (body['data'] as List).map((e) => Product.fromJson((e as Map).cast<String, dynamic>())).toList(),
      total: (body['meta'] as Map)['total'] as int,
    );
  }

  Future<Product> get(int id) async => Product.fromJson(await _api.get<Map<String, dynamic>>('/products/$id'));

  Future<({List<String> categories, List<String> brands})> suggestions() async {
    final data = await _api.get<Map<String, dynamic>>('/products/suggestions');
    return (categories: (data['categories'] as List).cast<String>(), brands: (data['brands'] as List).cast<String>());
  }

  Future<Product> create(ProductDraft draft, {PurchaseDraft? openingStock}) async => Product.fromJson(
    await _api.post<Map<String, dynamic>>(
      '/products',
      body: {...draft.toJson(), if (openingStock != null) 'openingStock': openingStock.toJson()},
    ),
  );

  Future<Product> update(int id, int version, ProductDraft draft) async => Product.fromJson(
    await _api.patch<Map<String, dynamic>>('/products/$id', body: {'version': version, ...draft.toJson()}),
  );

  Future<Product> setActive(int id, bool active) async =>
      Product.fromJson(await _api.post<Map<String, dynamic>>('/products/$id/${active ? 'activate' : 'deactivate'}'));

  Future<Product> receive(int id, PurchaseDraft purchase) async {
    final data = await _api.post<Map<String, dynamic>>('/products/$id/purchases', body: purchase.toJson());
    return Product.fromJson((data['product'] as Map).cast<String, dynamic>());
  }

  /// [quantity] is always positive; [stockIn] decides the direction.
  Future<Product> adjust(
    int id, {
    required bool stockIn,
    required int quantity,
    required AdjustmentReason reason,
    String? note,
  }) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/products/$id/adjustments',
      body: {'direction': stockIn ? 'IN' : 'OUT', 'quantity': quantity, 'reason': reason.key, 'note': note},
    );
    return Product.fromJson((data['product'] as Map).cast<String, dynamic>());
  }

  Future<({List<StockMovement> items, String? nextCursor})> movements(int id, {String? cursor, int limit = 30}) async {
    final body = await _api.getEnvelope('/products/$id/movements', query: {'limit': limit, 'cursor': ?cursor});
    return (
      items: (body['data'] as List).map((e) => StockMovement.fromJson((e as Map).cast<String, dynamic>())).toList(),
      nextCursor: (body['meta'] as Map)['nextCursor'] as String?,
    );
  }
}
