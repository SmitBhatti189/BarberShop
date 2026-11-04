import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Small key/value store backed by the OS keychain/keystore (iOS/macOS
/// Keychain, Android Keystore, Windows DPAPI). Abstracted so tests can use
/// [InMemorySecureStore].
abstract class SecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class PlatformSecureStore implements SecureStore {
  PlatformSecureStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class InMemorySecureStore implements SecureStore {
  InMemorySecureStore([Map<String, String>? initial]) : _values = {...?initial};

  final Map<String, String> _values;

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

abstract final class SecureStoreKeys {
  static const String accessToken = 'auth.accessToken';
  static const String refreshToken = 'auth.refreshToken';
  static const String serverUrl = 'server.baseUrl';
  static const String themeMode = 'ui.themeMode';
  static const String sidebarCollapsed = 'ui.sidebarCollapsed';
}
