import 'package:flutter/foundation.dart';

export '../../../core/domain/status_filter.dart';

/// A service the salon offers ("Haircut", "Haircut + Beard"), with its
/// current price and how long it takes. Named SalonService to avoid clashing
/// with Flutter's own "service" terms.
@immutable
class SalonService {
  const SalonService({
    required this.id,
    required this.name,
    required this.price,
    required this.durationMinutes,
    required this.isActive,
    required this.version,
    this.category,
    this.description,
  });

  factory SalonService.fromJson(Map<String, dynamic> json) => SalonService(
    id: json['id'] as int,
    name: json['name'] as String,
    category: json['category'] as String?,
    description: json['description'] as String?,
    price: json['price'] as String,
    durationMinutes: json['durationMinutes'] as int,
    isActive: json['isActive'] as bool,
    version: json['version'] as int,
  );

  final int id;
  final String name;
  final String? category;
  final String? description;

  /// "200.00" — current price; bills keep their own copy.
  final String price;
  final int durationMinutes;
  final bool isActive;
  final int version;
}

@immutable
class ServiceDraft {
  const ServiceDraft({
    required this.name,
    required this.price,
    required this.durationMinutes,
    this.category,
    this.description,
  });

  final String name;
  final String? category;
  final String? description;
  final String price;
  final int durationMinutes;

  Map<String, dynamic> toJson() => {
    'name': name,
    'category': category,
    'description': description,
    'price': price,
    'durationMinutes': durationMinutes,
  };
}

/// 30 → "30 min", 75 → "1 h 15 min", 60 → "1 h".
String formatDuration(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m min';
  return m == 0 ? '$h h' : '$h h $m min';
}
