import 'package:dio/dio.dart';

import '../../config/app_strings.dart';

/// Error from the API, decoded from `{ error: { code, message, details } }`,
/// or a client-side failure (no network, timeout). UI shows [message].
class ApiException implements Exception {
  const ApiException({required this.code, required this.message, this.statusCode, this.details});

  factory ApiException.fromDio(DioException e) {
    final response = e.response;
    final data = response?.data;
    if (data is Map && data['error'] is Map) {
      final error = data['error'] as Map;
      return ApiException(
        code: error['code']?.toString() ?? 'UNKNOWN',
        message: error['message']?.toString() ?? AppStrings.genericError,
        statusCode: response?.statusCode,
        details: error['details'],
      );
    }
    final isNetwork = switch (e.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout => true,
      _ => false,
    };
    return ApiException(
      code: isNetwork ? 'NETWORK' : 'UNKNOWN',
      message: isNetwork ? AppStrings.networkError : AppStrings.genericError,
      statusCode: response?.statusCode,
    );
  }

  final String code;
  final String message;
  final int? statusCode;
  final Object? details;

  bool get isNetwork => code == 'NETWORK';
  bool get isUnauthorized => statusCode == 401;

  /// Field-level validation messages keyed by field path (e.g. `body.name`).
  Map<String, String> get fieldErrors {
    final d = details;
    if (d is! List) return const {};
    return {
      for (final item in d)
        if (item is Map && item['field'] != null) item['field'].toString(): item['message']?.toString() ?? '',
    };
  }

  @override
  String toString() => 'ApiException($code, $statusCode): $message';
}

/// Server field errors keyed by the form's own field names
/// (`body.login.username` → `username`, `body.openingStock.unitCost` → `unitCost`).
Map<String, String> formFieldErrors(ApiException e) => {
  for (final entry in e.fieldErrors.entries) entry.key.split('.').last: entry.value,
};
