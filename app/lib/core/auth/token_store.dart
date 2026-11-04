import '../storage/secure_store.dart';
import 'auth_models.dart';

/// Holds the current tokens in memory (fast, read on every request) and
/// mirrors them to secure storage so a session survives an app restart.
class TokenStore {
  TokenStore(this._store);

  final SecureStore _store;
  TokenPair? _tokens;

  TokenPair? get current => _tokens;

  Future<TokenPair?> load() async {
    final access = await _store.read(SecureStoreKeys.accessToken);
    final refresh = await _store.read(SecureStoreKeys.refreshToken);
    _tokens = (access != null && refresh != null) ? TokenPair(accessToken: access, refreshToken: refresh) : null;
    return _tokens;
  }

  Future<void> save(TokenPair tokens) async {
    _tokens = tokens;
    await _store.write(SecureStoreKeys.accessToken, tokens.accessToken);
    await _store.write(SecureStoreKeys.refreshToken, tokens.refreshToken);
  }

  Future<void> clear() async {
    _tokens = null;
    await _store.delete(SecureStoreKeys.accessToken);
    await _store.delete(SecureStoreKeys.refreshToken);
  }
}
