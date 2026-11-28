import '../../../core/network/api_client.dart';
import '../domain/pay.dart';

/// `/compensation` endpoints. The commission rule itself lives on the server.
class CompensationApi {
  CompensationApi(this._api);

  final ApiClient _api;

  Future<String> salonDefault() async =>
      (await _api.get<Map<String, dynamic>>('/compensation/default'))['defaultCommissionPct'] as String;

  Future<String> setSalonDefault(String pct) async =>
      (await _api.put<Map<String, dynamic>>(
            '/compensation/default',
            body: {'defaultCommissionPct': pct},
          ))['defaultCommissionPct']
          as String;

  Future<List<PaySummary>> summaries() async => (await _api.get<List<dynamic>>(
    '/compensation/staff',
  )).map((e) => PaySummary.fromJson((e as Map).cast<String, dynamic>())).toList();

  Future<StaffPay> staffPay(int staffId) async =>
      StaffPay.fromJson(await _api.get<Map<String, dynamic>>('/compensation/staff/$staffId'));

  /// [monthlySalary] null = commission-based. Only [rates] listed are changed.
  Future<StaffPay> save(int staffId, {required String? monthlySalary, required List<RateChange> rates}) async =>
      StaffPay.fromJson(
        await _api.put<Map<String, dynamic>>(
          '/compensation/staff/$staffId',
          body: {'monthlySalary': monthlySalary, 'rates': rates.map((r) => r.toJson()).toList()},
        ),
      );
}
