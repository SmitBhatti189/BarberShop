import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../data/staff_api.dart';
import '../domain/employee.dart';

final staffApiProvider = Provider<StaffApi>((ref) => StaffApi(ref.watch(apiClientProvider)));

/// Roles for the employee form's picker; fetched once per form visit.
final rolesProvider = FutureProvider.autoDispose<List<RoleOption>>((ref) => ref.watch(staffApiProvider).roles());

/// One employee, for the edit screen.
final employeeProvider = FutureProvider.autoDispose.family<Employee, int>(
  (ref, id) => ref.watch(staffApiProvider).get(id),
);

@immutable
class StaffListState {
  const StaffListState({
    this.search = '',
    this.status = StatusFilter.active,
    this.items = const [],
    this.total = 0,
    this.loading = true,
    this.loadingMore = false,
    this.error,
  });

  final String search;
  final StatusFilter status;
  final List<Employee> items;
  final int total;
  final bool loading;
  final bool loadingMore;
  final ApiException? error;

  bool get hasMore => items.length < total;

  StaffListState copyWith({
    String? search,
    StatusFilter? status,
    List<Employee>? items,
    int? total,
    bool? loading,
    bool? loadingMore,
    ApiException? error,
    bool clearError = false,
  }) => StaffListState(
    search: search ?? this.search,
    status: status ?? this.status,
    items: items ?? this.items,
    total: total ?? this.total,
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
    error: clearError ? null : error ?? this.error,
  );
}

final staffListProvider = NotifierProvider.autoDispose<StaffListController, StaffListState>(StaffListController.new);

/// Employee list with search, status filter and "load more" paging.
class StaffListController extends Notifier<StaffListState> {
  // Ignores responses from searches the user has already moved past.
  int _request = 0;

  @override
  StaffListState build() {
    Future.microtask(reload);
    return const StaffListState();
  }

  StaffApi get _api => ref.read(staffApiProvider);

  Future<void> setSearch(String search) async {
    if (search == state.search) return;
    state = state.copyWith(search: search);
    await reload();
  }

  Future<void> setStatus(StatusFilter status) async {
    if (status == state.status) return;
    state = state.copyWith(status: status);
    await reload();
  }

  Future<void> reload() async {
    final request = ++_request;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final page = await _api.list(search: state.search, status: state.status);
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
      final page = await _api.list(search: state.search, status: state.status, offset: state.items.length);
      if (request != _request || !ref.mounted) return;
      state = state.copyWith(items: [...state.items, ...page.items], total: page.total, loadingMore: false);
    } on ApiException catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(loadingMore: false, error: e);
    }
  }
}
