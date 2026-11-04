import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_strings.dart';
import '../network/api_exception.dart';
import '../providers.dart';
import '../server/server_address.dart';
import '../storage/secure_store.dart';
import 'auth_models.dart';
import 'auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(ref.watch(apiClientProvider)));

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

/// Convenience: the signed-in user, or null.
final currentUserProvider = Provider<CurrentUser?>((ref) {
  final state = ref.watch(authControllerProvider);
  return state is AuthSignedIn ? state.user : null;
});

/// Owns the sign-in lifecycle: server address → restore session → login/logout.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    unawaited(Future.microtask(_restore));
    return const AuthLoading();
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> _restore() async {
    final env = ref.read(appEnvProvider);
    final store = ref.read(secureStoreProvider);
    final api = ref.read(apiClientProvider);

    final saved = env.allowServerOverride ? await store.read(SecureStoreKeys.serverUrl) : null;
    final baseUrl = saved ?? env.defaultApiBaseUrl;
    if (baseUrl == null) {
      state = const AuthNeedsServer();
      return;
    }
    api.baseUrl = baseUrl;

    final tokens = await ref.read(tokenStoreProvider).load();
    if (tokens == null) {
      state = const AuthSignedOut();
      return;
    }
    try {
      state = AuthSignedIn(await _repo.me());
    } on ApiException catch (e) {
      // Offline at start-up keeps the tokens so the next attempt can succeed.
      if (!e.isNetwork) await ref.read(tokenStoreProvider).clear();
      state = AuthSignedOut(message: e.isNetwork ? e.message : null);
    }
  }

  /// Checks that [input] is a reachable Barbershop server, then saves it.
  /// Returns an error message, or null on success.
  Future<String?> setServer(String input) async {
    final baseUrl = normalizeServerAddress(input);
    if (baseUrl == null) return 'Enter an address like 192.168.1.10:8080';
    final api = ref.read(apiClientProvider);
    try {
      final body = await api.probe('$baseUrl/health');
      final data = body['data'];
      if (data is! Map || data['status'] == null) return 'That address is not a Barbershop server.';
    } on ApiException catch (e) {
      return e.isNetwork ? 'No server answered at $baseUrl' : e.message;
    }
    api.baseUrl = baseUrl;
    await ref.read(secureStoreProvider).write(SecureStoreKeys.serverUrl, baseUrl);
    await ref.read(tokenStoreProvider).clear();
    state = const AuthSignedOut();
    return null;
  }

  /// Lets the user re-open the server screen (dev builds only).
  void changeServer() {
    if (ref.read(appEnvProvider).allowServerOverride) state = const AuthNeedsServer();
  }

  /// Returns an error message, or null on success.
  Future<String?> login(String username, String password) async {
    try {
      final result = await _repo.login(username, password, deviceLabel: _deviceLabel());
      await ref.read(tokenStoreProvider).save(result.tokens);
      state = AuthSignedIn(result.user);
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<void> logout() async {
    try {
      await _repo.logout();
    } on ApiException {
      // Server unreachable: still sign out locally; the session expires server-side.
    }
    await ref.read(tokenStoreProvider).clear();
    state = const AuthSignedOut();
  }

  /// Called by ApiClient when a refresh fails.
  void onSessionExpired() {
    if (state is AuthSignedIn) state = const AuthSignedOut(message: AppStrings.sessionExpired);
  }

  String _deviceLabel() => kIsWeb ? 'web' : defaultTargetPlatform.name;
}
