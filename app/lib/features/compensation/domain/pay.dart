import 'package:flutter/foundation.dart';

/// Why a rate applies (decided by the server's commission rule).
enum RateSource {
  /// This employee's own rate for the item.
  specific,

  /// No own rate and no salary → the salon default.
  salonDefault,

  /// Salaried and no own rate → no commission.
  none;

  static RateSource fromApi(String v) => switch (v) {
    'SPECIFIC' => specific,
    'DEFAULT' => salonDefault,
    _ => none,
  };
}

enum PayItemType {
  service('SERVICE'),
  product('PRODUCT');

  const PayItemType(this.api);
  final String api;
}

/// One service or product on an employee's pay page.
@immutable
class PayItem {
  const PayItem({
    required this.type,
    required this.itemId,
    required this.name,
    required this.price,
    required this.source,
    this.detail,
    this.ratePct,
    this.effectiveRatePct,
  });

  factory PayItem.fromJson(PayItemType type, Map<String, dynamic> j) => PayItem(
    type: type,
    itemId: j['itemId'] as int,
    name: j['name'] as String,
    detail: j['detail'] as String?,
    price: j['price'] as String,
    ratePct: j['ratePct'] as String?,
    effectiveRatePct: j['effectiveRatePct'] as String?,
    source: RateSource.fromApi(j['source'] as String),
  );

  final PayItemType type;
  final int itemId;
  final String name;
  final String? detail;
  final String price;

  /// This employee's own rate, if set.
  final String? ratePct;

  /// What applies today (own rate, salon default, or none).
  final String? effectiveRatePct;
  final RateSource source;

  String get key => '${type.api}:$itemId';
}

@immutable
class StaffPay {
  const StaffPay({
    required this.staffId,
    required this.fullName,
    required this.roleName,
    required this.performsServices,
    required this.salonDefaultPct,
    required this.services,
    required this.products,
    this.monthlySalary,
  });

  factory StaffPay.fromJson(Map<String, dynamic> j) {
    final staff = (j['staff'] as Map).cast<String, dynamic>();
    List<PayItem> items(String key, PayItemType type) =>
        (j[key] as List).map((e) => PayItem.fromJson(type, (e as Map).cast<String, dynamic>())).toList();
    return StaffPay(
      staffId: staff['id'] as int,
      fullName: staff['fullName'] as String,
      roleName: staff['roleName'] as String,
      performsServices: staff['performsServices'] as bool,
      monthlySalary: j['monthlySalary'] as String?,
      salonDefaultPct: j['salonDefaultPct'] as String,
      services: items('services', PayItemType.service),
      products: items('products', PayItemType.product),
    );
  }

  final int staffId;
  final String fullName;
  final String roleName;
  final bool performsServices;

  /// Null = commission-based.
  final String? monthlySalary;
  final String salonDefaultPct;
  final List<PayItem> services;
  final List<PayItem> products;
}

/// One row of the employee list on the pay page.
@immutable
class PaySummary {
  const PaySummary({
    required this.staffId,
    required this.fullName,
    required this.roleName,
    required this.performsServices,
    required this.specificRates,
    this.monthlySalary,
  });

  factory PaySummary.fromJson(Map<String, dynamic> j) => PaySummary(
    staffId: j['staffId'] as int,
    fullName: j['fullName'] as String,
    roleName: j['roleName'] as String,
    performsServices: j['performsServices'] as bool,
    monthlySalary: j['monthlySalary'] as String?,
    specificRates: j['specificRates'] as int,
  );

  final int staffId;
  final String fullName;
  final String roleName;
  final bool performsServices;
  final String? monthlySalary;
  final int specificRates;
}

/// A rate change to send: null [ratePct] removes the employee's own rate.
@immutable
class RateChange {
  const RateChange(this.type, this.itemId, this.ratePct);
  final PayItemType type;
  final int itemId;
  final String? ratePct;

  Map<String, dynamic> toJson() => {'itemType': type.api, 'itemId': itemId, 'ratePct': ratePct};
}
