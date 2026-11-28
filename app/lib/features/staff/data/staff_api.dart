import '../../../core/network/api_client.dart';
import '../domain/employee.dart';

/// `/staff` and `/roles` endpoints. All rules are enforced by the server;
/// this class only moves data.
class StaffApi {
  StaffApi(this._api);

  final ApiClient _api;

  static const pageSize = 50;

  Future<EmployeePage> list({String? search, StatusFilter status = StatusFilter.active, int offset = 0}) async {
    final body = await _api.getEnvelope(
      '/staff',
      query: {
        if (search != null && search.isNotEmpty) 'search': search,
        'status': status.name,
        'limit': pageSize,
        'offset': offset,
      },
    );
    final items = (body['data'] as List).map((e) => Employee.fromJson((e as Map).cast<String, dynamic>())).toList();
    return EmployeePage(items: items, total: (body['meta'] as Map)['total'] as int);
  }

  Future<Employee> get(int id) async => Employee.fromJson(await _api.get<Map<String, dynamic>>('/staff/$id'));

  Future<Employee> create(EmployeeDraft draft, {String? username, String? password}) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/staff',
      body: {
        ...draft.toJson(),
        if (username != null && password != null) 'login': {'username': username, 'password': password},
      },
    );
    return Employee.fromJson(data);
  }

  Future<Employee> update(int id, int version, EmployeeDraft draft) async => Employee.fromJson(
    await _api.patch<Map<String, dynamic>>('/staff/$id', body: {'version': version, ...draft.toJson()}),
  );

  Future<Employee> setActive(int id, bool active) async =>
      Employee.fromJson(await _api.post<Map<String, dynamic>>('/staff/$id/${active ? 'activate' : 'deactivate'}'));

  Future<Employee> setLogin(int id, String username, String password) async => Employee.fromJson(
    await _api.put<Map<String, dynamic>>('/staff/$id/login', body: {'username': username, 'password': password}),
  );

  Future<Employee> removeLogin(int id) async =>
      Employee.fromJson(await _api.delete<Map<String, dynamic>>('/staff/$id/login'));

  Future<List<RoleOption>> roles() async {
    final data = await _api.get<List<dynamic>>('/roles');
    return data.map((e) => RoleOption.fromJson((e as Map).cast<String, dynamic>())).toList();
  }
}
