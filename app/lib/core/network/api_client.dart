import 'dart:async';

import 'package:dio/dio.dart';

import '../../config/env/app_env.dart';
import '../auth/auth_models.dart';
import '../auth/token_store.dart';
import 'api_exception.dart';

/// HTTP client for the REST API.
///
/// * Attaches the access token to every request.
/// * On a 401 it refreshes the token ONCE (concurrent failures share the same
///   refresh — the backend treats a re-used refresh token as theft) and
///   retries the original request.
/// * If the refresh fails, [onSessionExpired] signs the user out.
/// * Unwraps the `{ data }` envelope and turns failures into [ApiException].
class ApiClient {
  ApiClient({
    required AppEnv env,
    required TokenStore tokens,
    required void Function() onSessionExpired,
    String? baseUrl,
    HttpClientAdapter? adapter,
  }) : _tokens = tokens,
       _onSessionExpired = onSessionExpired,
       _dio = Dio(
         BaseOptions(
           baseUrl: baseUrl ?? '',
           connectTimeout: env.connectTimeout,
           receiveTimeout: env.receiveTimeout,
           contentType: Headers.jsonContentType,
           responseType: ResponseType.json,
         ),
       ) {
    if (adapter != null) _dio.httpClientAdapter = adapter;
    _dio.interceptors.add(InterceptorsWrapper(onRequest: _attachToken, onError: _onError));
  }

  final Dio _dio;
  final TokenStore _tokens;
  final void Function() _onSessionExpired;
  Future<bool>? _refreshInFlight;

  static const _skipAuthKey = 'skipAuth';
  static const _retriedKey = 'retried';

  String get baseUrl => _dio.options.baseUrl;
  set baseUrl(String value) => _dio.options.baseUrl = value;

  Future<T> get<T>(String path, {Map<String, dynamic>? query, CancelToken? cancelToken}) =>
      _send(() => _dio.get<Object?>(path, queryParameters: query, cancelToken: cancelToken));

  Future<T> post<T>(String path, {Object? body, bool authenticated = true, Map<String, String>? headers}) =>
      _send(() => _dio.post<Object?>(path, data: body, options: _options(authenticated, headers)));

  Future<T> patch<T>(String path, {Object? body, Map<String, String>? headers}) =>
      _send(() => _dio.patch<Object?>(path, data: body, options: _options(true, headers)));

  Future<T> put<T>(String path, {Object? body}) => _send(() => _dio.put<Object?>(path, data: body));

  Future<T> delete<T>(String path) => _send<T>(() => _dio.delete<Object?>(path));

  /// GET returning the whole envelope (`data` and `meta`) — for paged lists.
  Future<Map<String, dynamic>> getEnvelope(String path, {Map<String, dynamic>? query}) async {
    try {
      final res = await _dio.get<Object?>(path, queryParameters: query);
      return (res.data as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw e.error is ApiException ? e.error! as ApiException : ApiException.fromDio(e);
    }
  }

  /// Calls without any token handling (health checks against a candidate server).
  Future<Map<String, dynamic>> probe(String absoluteUrl) async {
    try {
      final res = await _dio.get<Object?>(absoluteUrl, options: Options(extra: {_skipAuthKey: true}));
      return (res.data as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Options _options(bool authenticated, Map<String, String>? headers) =>
      Options(extra: {_skipAuthKey: !authenticated}, headers: headers);

  Future<T> _send<T>(Future<Response<Object?>> Function() request) async {
    try {
      final res = await request();
      final body = res.data;
      if (body is Map && body.containsKey('data')) return body['data'] as T;
      return body as T;
    } on DioException catch (e) {
      throw e.error is ApiException ? e.error! as ApiException : ApiException.fromDio(e);
    }
  }

  void _attachToken(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _tokens.current?.accessToken;
    if (options.extra[_skipAuthKey] != true && token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  Future<void> _onError(DioException error, ErrorInterceptorHandler handler) async {
    final options = error.requestOptions;
    final eligible =
        error.response?.statusCode == 401 &&
        options.extra[_skipAuthKey] != true &&
        options.extra[_retriedKey] != true &&
        _tokens.current != null;
    if (!eligible) return handler.next(error);

    final refreshed = await _refreshOnce();
    if (!refreshed) {
      _onSessionExpired();
      return handler.next(error);
    }
    try {
      options.extra[_retriedKey] = true;
      options.headers['Authorization'] = 'Bearer ${_tokens.current!.accessToken}';
      handler.resolve(await _dio.fetch<Object?>(options));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  /// Single-flight refresh: every caller awaits the same future.
  Future<bool> _refreshOnce() => _refreshInFlight ??= _refresh().whenComplete(() => _refreshInFlight = null);

  Future<bool> _refresh() async {
    final refreshToken = _tokens.current?.refreshToken;
    if (refreshToken == null) return false;
    try {
      final res = await _dio.post<Object?>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
        options: Options(extra: {_skipAuthKey: true}),
      );
      final data = ((res.data as Map)['data'] as Map).cast<String, dynamic>();
      await _tokens.save(
        TokenPair(accessToken: data['accessToken'] as String, refreshToken: data['refreshToken'] as String),
      );
      return true;
    } on DioException {
      await _tokens.clear();
      return false;
    }
  }
}
