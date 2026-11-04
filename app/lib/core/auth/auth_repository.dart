import '../network/api_client.dart';
import 'auth_models.dart';

/// Thin data-layer wrapper over the /auth endpoints.
class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  Future<({TokenPair tokens, CurrentUser user})> login(String username, String password, {String? deviceLabel}) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/auth/login',
      authenticated: false,
      body: {'username': username, 'password': password, 'deviceLabel': ?deviceLabel},
    );
    return (
      tokens: TokenPair(accessToken: data['accessToken'] as String, refreshToken: data['refreshToken'] as String),
      user: CurrentUser.fromJson((data['user'] as Map).cast<String, dynamic>()),
    );
  }

  Future<CurrentUser> me() async {
    final data = await _api.get<Map<String, dynamic>>('/auth/me');
    return CurrentUser.fromJson(data);
  }

  Future<void> logout() => _api.post<void>('/auth/logout');
}
