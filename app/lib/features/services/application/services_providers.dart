import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../data/services_api.dart';
import '../domain/salon_service.dart';

final servicesApiProvider = Provider<ServicesApi>((ref) => ServicesApi(ref.watch(apiClientProvider)));

final serviceCategoriesProvider = FutureProvider.autoDispose<List<String>>(
  (ref) => ref.watch(servicesApiProvider).categories(),
);

final serviceProvider = FutureProvider.autoDispose.family<SalonService, int>(
  (ref, id) => ref.watch(servicesApiProvider).get(id),
);

@immutable
class ServicesListState {
  const ServicesListState({
    this.search = '',
    this.category,
    this.status = StatusFilter.active,
    this.items = const [],
    this.total = 0,
    this.loading = true,
    this.error,
  });

  final String search;
  final String? category;
  final StatusFilter status;
  final List<SalonService> items;
  final int total;
  final bool loading;
  final ApiException? error;

  bool get filtered => search.isNotEmpty || category != null || status != StatusFilter.active;

  ServicesListState copyWith({
    String? search,
    String? category,
    bool clearCategory = false,
    StatusFilter? status,
    List<SalonService>? items,
    int? total,
    bool? loading,
    ApiException? error,
    bool clearError = false,
  }) => ServicesListState(
    search: search ?? this.search,
    category: clearCategory ? null : category ?? this.category,
    status: status ?? this.status,
    items: items ?? this.items,
    total: total ?? this.total,
    loading: loading ?? this.loading,
    error: clearError ? null : error ?? this.error,
  );
}

final servicesListProvider = NotifierProvider.autoDispose<ServicesListController, ServicesListState>(
  ServicesListController.new,
);

/// Service list with search, category and status filters. A salon has tens of
/// services, so one page of 100 covers it.
class ServicesListController extends Notifier<ServicesListState> {
  int _request = 0;

  @override
  ServicesListState build() {
    Future.microtask(reload);
    return const ServicesListState();
  }

  Future<void> setSearch(String value) => _apply(state.copyWith(search: value));
  Future<void> setCategory(String? value) => _apply(state.copyWith(category: value, clearCategory: value == null));
  Future<void> setStatus(StatusFilter value) => _apply(state.copyWith(status: value));

  Future<void> _apply(ServicesListState next) async {
    state = next;
    await reload();
  }

  Future<void> reload() async {
    final request = ++_request;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final page = await ref
          .read(servicesApiProvider)
          .list(search: state.search, category: state.category, status: state.status);
      if (request != _request || !ref.mounted) return;
      state = state.copyWith(items: page.items, total: page.total, loading: false);
    } on ApiException catch (e) {
      if (request != _request || !ref.mounted) return;
      state = state.copyWith(loading: false, error: e);
    }
  }
}
