import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/compensation_api.dart';
import '../domain/pay.dart';

final compensationApiProvider = Provider<CompensationApi>((ref) => CompensationApi(ref.watch(apiClientProvider)));

final salonDefaultProvider = FutureProvider.autoDispose<String>(
  (ref) => ref.watch(compensationApiProvider).salonDefault(),
);

final paySummariesProvider = FutureProvider.autoDispose<List<PaySummary>>(
  (ref) => ref.watch(compensationApiProvider).summaries(),
);

final staffPayProvider = FutureProvider.autoDispose.family<StaffPay, int>(
  (ref, staffId) => ref.watch(compensationApiProvider).staffPay(staffId),
);

/// Which employee the pay page is showing (null until the list loads).
final selectedPayStaffProvider = NotifierProvider.autoDispose<SelectedPayStaff, int?>(SelectedPayStaff.new);

class SelectedPayStaff extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int staffId) => state = staffId;
}
