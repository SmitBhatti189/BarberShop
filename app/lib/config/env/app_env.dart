import 'package:flutter/foundation.dart';

/// Build-time environment, set with `--dart-define`:
///
/// ```
/// flutter run --dart-define=APP_ENV=dev --dart-define=API_BASE_URL=http://192.168.1.10:8080/api/v1
/// ```
///
/// In `dev` the server address can also be changed at runtime from the app
/// (salon LAN testing, where the server PC's IP may change).
enum AppEnvironment { dev, prod }

class AppEnv {
  const AppEnv({
    required this.environment,
    required this.defaultApiBaseUrl,
    required this.connectTimeout,
    required this.receiveTimeout,
  });

  factory AppEnv.fromDefines() {
    const env = String.fromEnvironment('APP_ENV', defaultValue: 'dev');
    const url = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    return AppEnv(
      environment: env == 'prod' ? AppEnvironment.prod : AppEnvironment.dev,
      defaultApiBaseUrl: url.isNotEmpty ? url : (serverSetupEnabled ? null : builtInApiBaseUrl()),
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 20),
    );
  }

  final AppEnvironment environment;

  /// Server address the app starts with. Null ⇒ the user is asked on first
  /// launch (only possible while [serverSetupEnabled] is on).
  final String? defaultApiBaseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;

  bool get isDev => environment == AppEnvironment.dev;

  /// TEMPORARILY OFF (owner request, 2026-11-19): the app does not ask for
  /// the server address and has no "Change server" button; it always uses
  /// `API_BASE_URL`, or [builtInApiBaseUrl] when none is given. Set to true
  /// to bring back the "Connect to the salon" screen (ServerSetupScreen,
  /// still in the code) and the button on the login screen.
  static const bool serverSetupEnabled = false;

  /// Port the API listens on (see server/.env.example).
  static const int defaultApiPort = 8080;

  /// Server used when no `API_BASE_URL` is given while server setup is off:
  /// in a browser, the PC that served the page; on a device, this machine.
  static String builtInApiBaseUrl() {
    final host = kIsWeb && Uri.base.host.isNotEmpty ? Uri.base.host : 'localhost';
    return 'http://$host:$defaultApiPort$apiPath';
  }

  /// Only dev builds let the user point the app at another server — and only
  /// while [serverSetupEnabled] is on.
  bool get allowServerOverride => isDev && serverSetupEnabled;

  /// API path appended to a bare server address such as `http://192.168.1.10:8080`.
  static const String apiPath = '/api/v1';
}
