import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../data/inventory_api.dart';
import '../domain/product.dart';

final inventoryApiProvider = Provider<InventoryApi>((ref) => InventoryApi(ref.watch(apiClientProvider)));

/// Categories and brands already in use, offered as one-tap suggestions.
final productSuggestionsProvider = FutureProvider.autoDispose<({List<String> categories, List<String> brands})>(
  (ref) => ref.watch(inventoryApiProvider).suggestions(),
);

final productProvider = FutureProvider.autoDispose.family<Product, int>(
  (ref, id) => ref.watch(inventoryApiProvider).get(id),
);

@immutable
class InventoryListState {
  const InventoryListState({
    this.search = '',
    this.category,
    this.status = StatusFilter.active,
    this.lowStockOnly = false,
    this.items = const [],
    this.total = 0,
    this.loading = true,
    this.loadingMore = false,
    this.error,
  });

  final String search;
  final String? category;
  final StatusFilter status;
  final bool lowStockOnly;
  final List<Product> items;
  final int total;
  final bool loading;
  final bool loadingMore;
  final ApiException? error;

  bool get hasMore => items.length < total;
  bool get filtered => search.isNotEmpty || category != null || lowStockOnly || status != StatusFilter.active;

  InventoryListState copyWith({
    String? search,
    String? category,
    bool clearCategory = false,
    StatusFilter? status,
    bool? lowStockOnly,
    List<Product>? items,
    int? total,
    bool? loading,
    bool? loadingMore,
    ApiException? error,
    bool clearError = false,
  }) => InventoryListState(
    search: search ?? this.search,
    category: clearCategory ? null : category ?? this.category,
    status: status ?? this.status,
    lowStockOnly: lowStockOnly ?? this.lowStockOnly,
    items: items ?? this.items,
    total: total ?? this.total,
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
    error: clearError ? null : error ?? this.error,
  );
}

final inventoryListProvider = NotifierProvider.autoDispose<InventoryListController, InventoryListState>(
  InventoryListController.new,
);

/// Product list with search, category, status and low-stock filters, paged.
class InventoryListController extends Notifier<InventoryListState> {
  int _request = 0; // ignores answers to filters the user has moved past

  @override
  InventoryListState build() {
    Future.microtask(reload);
    return const InventoryListState();
  }

  InventoryApi get _api => ref.read(inventoryApiProvider);

  Future<void> setSearch(String value) => _apply(state.copyWith(search: value));
  Future<void> setCategory(String? value) => _apply(state.copyWith(category: value, clearCategory: value == null));
  Future<void> setStatus(StatusFilter value) => _apply(state.copyWith(status: value));
  Future<void> setLowStockOnly(bool value) => _apply(state.copyWith(lowStockOnly: value));

  Future<void> _apply(InventoryListState next) async {
    state = next;
    await reload();
  }

  Future<void> reload() async {
    final request = ++_request;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final page = await _fetch(0);
      if (request != _request || !ref.mounted) return;
      state = state.copyWith(items: page.items, total: page.total, loading: false);
    } on ApiException catch (e) {
      if (request != _request || !ref.mounted) return;
      state = state.copyWith(loading: false, error: e);
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore) return;
    final request = _request;
    state = state.copyWith(loadingMore: true);
    try {
      final page = await _fetch(state.items.length);
      if (request != _request || !ref.mounted) return;
      state = state.copyWith(items: [...state.items, ...page.items], total: page.total, loadingMore: false);
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(loadingMore: false, error: e);
    }
  }

  Future<({List<Product> items, int total})> _fetch(int offset) => _api.list(
    search: state.search,
    category: state.category,
    status: state.status,
    lowStockOnly: state.lowStockOnly,
    offset: offset,
  );
}

@immutable
class MovementsState {
  const MovementsState({
    this.items = const [],
    this.nextCursor,
    this.loading = true,
    this.loadingMore = false,
    this.error,
  });

  final List<StockMovement> items;
  final String? nextCursor;
  final bool loading;
  final bool loadingMore;
  final ApiException? error;
}

final movementsProvider = NotifierProvider.autoDispose.family<MovementsController, MovementsState, int>(
  MovementsController.new,
);

/// A product's stock history, newest first, with "show more".
class MovementsController extends Notifier<MovementsState> {
  MovementsController(this.productId);

  final int productId;

  @override
  MovementsState build() {
    Future.microtask(reload);
    return const MovementsState();
  }

  Future<void> reload() async {
    try {
      final page = await ref.read(inventoryApiProvider).movements(productId);
      if (!ref.mounted) return;
      state = MovementsState(items: page.items, nextCursor: page.nextCursor, loading: false);
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      state = MovementsState(loading: false, error: e);
    }
  }

  Future<void> loadMore() async {
    final cursor = state.nextCursor;
    if (cursor == null || state.loadingMore) return;
    state = MovementsState(items: state.items, nextCursor: cursor, loading: false, loadingMore: true);
    try {
      final page = await ref.read(inventoryApiProvider).movements(productId, cursor: cursor);
      if (!ref.mounted) return;
      state = MovementsState(items: [...state.items, ...page.items], nextCursor: page.nextCursor, loading: false);
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      state = MovementsState(items: state.items, nextCursor: cursor, loading: false, error: e);
    }
  }
}
