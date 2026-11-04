import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env/app_env.dart';
import 'auth/auth_controller.dart';
import 'auth/token_store.dart';
import 'network/api_client.dart';
import 'storage/secure_store.dart';

/// Root dependencies. `main.dart` (and tests) may override the first two.
final appEnvProvider = Provider<AppEnv>((ref) => AppEnv.fromDefines());

final secureStoreProvider = Provider<SecureStore>((ref) => PlatformSecureStore());

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore(ref.watch(secureStoreProvider)));

/// One ApiClient for the whole app (one connection pool, one refresh lock).
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    env: ref.watch(appEnvProvider),
    tokens: ref.watch(tokenStoreProvider),
    // Read lazily: the auth controller itself depends on this client.
    onSessionExpired: () => ref.read(authControllerProvider.notifier).onSessionExpired(),
  );
});
