import 'package:flutter/foundation.dart';

export '../../../core/domain/status_filter.dart';

/// A product with this branch's stock, as returned by `/products`.
/// Money values are strings ("1800.00") exactly as the server computed them.
@immutable
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.mrp,
    required this.defaultDiscountPct,
    required this.sellingPrice,
    required this.stockQuantity,
    required this.lowStockThreshold,
    required this.isLowStock,
    required this.isActive,
    required this.version,
    this.brand,
    this.category,
    this.lastPurchasePrice,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'] as int,
    name: json['name'] as String,
    brand: json['brand'] as String?,
    category: json['category'] as String?,
    mrp: json['mrp'] as String,
    defaultDiscountPct: json['defaultDiscountPct'] as String,
    sellingPrice: json['sellingPrice'] as String,
    lastPurchasePrice: json['lastPurchasePrice'] as String?,
    stockQuantity: json['stockQuantity'] as int,
    lowStockThreshold: json['lowStockThreshold'] as int,
    isLowStock: json['isLowStock'] as bool,
    isActive: json['isActive'] as bool,
    version: json['version'] as int,
  );

  final int id;
  final String name;
  final String? brand;
  final String? category;
  final String mrp;
  final String defaultDiscountPct;

  /// MRP less the default discount — what billing will charge by default.
  final String sellingPrice;

  /// Buying price of the most recent delivery.
  final String? lastPurchasePrice;
  final int stockQuantity;
  final int lowStockThreshold;
  final bool isLowStock;
  final bool isActive;
  final int version;

  String get displayName => brand == null ? name : '$name · $brand';
}

enum MovementType {
  purchase('Delivery'),
  sale('Sale'),
  adjustment('Adjustment'),
  saleReversal('Sale reversed');

  const MovementType(this.label);
  final String label;

  static MovementType fromApi(String value) => switch (value) {
    'PURCHASE' => purchase,
    'SALE' => sale,
    'SALE_REVERSAL' => saleReversal,
    _ => adjustment,
  };
}

/// Why stock was corrected by hand. Keys match the server's.
enum AdjustmentReason {
  damaged('DAMAGED', 'Damaged'),
  expired('EXPIRED', 'Expired'),
  usedInSalon('USED_IN_SALON', 'Used in the salon'),
  countCorrection('COUNT_CORRECTION', 'Count correction'),
  returnedToSupplier('RETURNED_TO_SUPPLIER', 'Returned to supplier'),
  other('OTHER', 'Other');

  const AdjustmentReason(this.key, this.label);
  final String key;
  final String label;

  static String labelFor(String? key) =>
      values.where((r) => r.key == key).map((r) => r.label).firstOrNull ?? (key ?? '');
}

/// One line of a product's stock history.
@immutable
class StockMovement {
  const StockMovement({
    required this.id,
    required this.type,
    required this.quantityDelta,
    required this.createdBy,
    required this.createdAt,
    this.unitCost,
    this.supplierName,
    this.invoiceNo,
    this.reason,
    this.note,
  });

  factory StockMovement.fromJson(Map<String, dynamic> json) => StockMovement(
    id: json['id'] as int,
    type: MovementType.fromApi(json['type'] as String),
    quantityDelta: json['quantityDelta'] as int,
    unitCost: json['unitCost'] as String?,
    supplierName: json['supplierName'] as String?,
    invoiceNo: json['invoiceNo'] as String?,
    reason: json['reason'] as String?,
    note: json['note'] as String?,
    createdBy: json['createdBy'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
  );

  final int id;
  final MovementType type;
  final int quantityDelta;
  final String? unitCost;
  final String? supplierName;
  final String? invoiceNo;
  final String? reason;
  final String? note;
  final String createdBy;
  final DateTime createdAt;
}

/// Product fields the form sends. Null brand/category clear them.
@immutable
class ProductDraft {
  const ProductDraft({
    required this.name,
    required this.mrp,
    required this.defaultDiscountPct,
    required this.lowStockThreshold,
    this.brand,
    this.category,
  });

  final String name;
  final String? brand;
  final String? category;
  final String mrp;
  final String defaultDiscountPct;
  final int lowStockThreshold;

  Map<String, dynamic> toJson() => {
    'name': name,
    'brand': brand,
    'category': category,
    'mrp': mrp,
    'defaultDiscountPct': defaultDiscountPct,
    'lowStockThreshold': lowStockThreshold,
  };
}

/// A delivery (also used for opening stock).
@immutable
class PurchaseDraft {
  const PurchaseDraft({required this.quantity, required this.unitCost, this.supplierName, this.invoiceNo, this.note});

  final int quantity;
  final String unitCost;
  final String? supplierName;
  final String? invoiceNo;
  final String? note;

  Map<String, dynamic> toJson() => {
    'quantity': quantity,
    'unitCost': unitCost,
    'supplierName': supplierName,
    'invoiceNo': invoiceNo,
    'note': note,
  };
}
