import 'dart:convert';
import 'dart:typed_data';

import 'package:barbershop_app/config/env/app_env.dart';
import 'package:barbershop_app/core/auth/auth_models.dart';
import 'package:barbershop_app/core/auth/token_store.dart';
import 'package:barbershop_app/core/network/api_client.dart';
import 'package:barbershop_app/core/network/api_exception.dart';
import 'package:barbershop_app/core/storage/secure_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake server: `/auth/refresh` issues token "fresh"; `/items` returns 401
/// unless called with "fresh".
class FakeAdapter implements HttpClientAdapter {
  int refreshCalls = 0;
  bool refreshFails = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path == '/auth/refresh') {
      refreshCalls++;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      if (refreshFails) {
        return _json(401, {
          'error': {'code': 'UNAUTHORIZED', 'message': 'Session expired'},
        });
      }
      return _json(200, {
        'data': {'accessToken': 'fresh', 'refreshToken': 'r2', 'expiresIn': 900, 'user': {}},
      });
    }
    if (options.path == '/broken') {
      return _json(422, {
        'error': {'code': 'STOCK_INSUFFICIENT', 'message': 'Not enough stock'},
      });
    }
    final auth = options.headers['Authorization'];
    if (auth != 'Bearer fresh') {
      return _json(401, {
        'error': {'code': 'UNAUTHORIZED', 'message': 'expired'},
      });
    }
    return _json(200, {
      'data': {'ok': true},
    });
  }

  ResponseBody _json(int status, Object body) => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

void main() {
  late FakeAdapter adapter;
  late TokenStore tokens;
  late int expiredCalls;
  late ApiClient client;

  setUp(() async {
    adapter = FakeAdapter();
    tokens = TokenStore(InMemorySecureStore());
    await tokens.save(const TokenPair(accessToken: 'stale', refreshToken: 'r1'));
    expiredCalls = 0;
    client = ApiClient(
      env: AppEnv.fromDefines(),
      tokens: tokens,
      onSessionExpired: () => expiredCalls++,
      baseUrl: 'http://server/api/v1',
      adapter: adapter,
    );
  });

  test('refreshes once for many concurrent 401s, then retries each request', () async {
    final results = await Future.wait(List.generate(5, (_) => client.get<Map<String, dynamic>>('/items')));
    expect(results.every((r) => r['ok'] == true), isTrue);
    expect(adapter.refreshCalls, 1);
    expect(tokens.current?.refreshToken, 'r2');
  });

  test('signs out when the refresh is rejected', () async {
    adapter.refreshFails = true;
    await expectLater(client.get<Object?>('/items'), throwsA(isA<ApiException>()));
    expect(expiredCalls, 1);
    expect(tokens.current, isNull);
  });

  test('decodes the error envelope', () async {
    await tokens.save(const TokenPair(accessToken: 'fresh', refreshToken: 'r1'));
    final error = await client
        .get<Object?>('/broken')
        .then<ApiException?>((_) => null, onError: (Object e) => e as ApiException);
    expect(error?.code, 'STOCK_INSUFFICIENT');
    expect(error?.statusCode, 422);
    expect(error?.message, 'Not enough stock');
  });
}
