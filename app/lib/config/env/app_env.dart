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
      defaultApiBaseUrl: url.isEmpty ? null : url,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 20),
    );
  }

  final AppEnvironment environment;

  /// Compile-time server address, if any. Null ⇒ the user is asked on first launch.
  final String? defaultApiBaseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;

  bool get isDev => environment == AppEnvironment.dev;

  /// Only dev builds let the user point the app at another server.
  bool get allowServerOverride => isDev;

  /// API path appended to a bare server address such as `http://192.168.1.10:8080`.
  static const String apiPath = '/api/v1';
}
