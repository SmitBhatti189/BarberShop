import '../../../core/network/api_client.dart';
import '../domain/salon_service.dart';

/// `/services` endpoints.
class ServicesApi {
  ServicesApi(this._api);

  final ApiClient _api;

  static const pageSize = 100;

  Future<({List<SalonService> items, int total})> list({
    String? search,
    String? category,
    StatusFilter status = StatusFilter.active,
    int offset = 0,
  }) async {
    final body = await _api.getEnvelope(
      '/services',
      query: {
        if (search != null && search.isNotEmpty) 'search': search,
        'category': ?category,
        'status': status.name,
        'limit': pageSize,
        'offset': offset,
      },
    );
    return (
      items: (body['data'] as List).map((e) => SalonService.fromJson((e as Map).cast<String, dynamic>())).toList(),
      total: (body['meta'] as Map)['total'] as int,
    );
  }

  Future<List<String>> categories() async => (await _api.get<List<dynamic>>('/services/categories')).cast<String>();

  Future<SalonService> get(int id) async =>
      SalonService.fromJson(await _api.get<Map<String, dynamic>>('/services/$id'));

  Future<SalonService> create(ServiceDraft draft) async =>
      SalonService.fromJson(await _api.post<Map<String, dynamic>>('/services', body: draft.toJson()));

  Future<SalonService> update(int id, int version, ServiceDraft draft) async => SalonService.fromJson(
    await _api.patch<Map<String, dynamic>>('/services/$id', body: {'version': version, ...draft.toJson()}),
  );

  Future<SalonService> setActive(int id, bool active) async => SalonService.fromJson(
    await _api.post<Map<String, dynamic>>('/services/$id/${active ? 'activate' : 'deactivate'}'),
  );
}
