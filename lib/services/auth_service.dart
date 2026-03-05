import '../data/api_client.dart';
import '../data/encrypted_local_storage.dart';
import '../domain/models/user.dart';
import '../platform/logger.dart';

/// Manages authentication lifecycle: login, token refresh, claims validation,
/// and tenant isolation checks.
///
/// Relationships (C4):
///   AuthService → Identity Provider (via ApiClient → DummyBackend)
///   AuthService → ApiClient : provides token/claims
class AuthService {
  final ApiClient _apiClient;
  final EncryptedLocalStorage _storage;

  User? _currentUser;
  String? _currentToken;

  AuthService({
    required ApiClient apiClient,
    required EncryptedLocalStorage storage,
  })  : _apiClient = apiClient,
        _storage = storage;

  User? get currentUser => _currentUser;
  String? get token => _currentToken;
  bool get isAuthenticated => _currentToken != null && _currentUser != null;

  /// Authenticate with email/password via identity provider.
  Future<User> login(String email, String password) async {
    AppLogger.log(LogLevel.info, 'AuthService.login($email)');
    final result = await _apiClient.login(email, password);

    _currentToken = result['token'] as String;
    _currentUser = User.fromJson(result['user'] as Map<String, dynamic>);

    // Persist token for session restore
    await _storage.saveSecure('auth_token', _currentToken!);
    await _storage.cacheData('current_user', _currentUser!.toJson());

    AppLogger.telemetry('login_success', properties: {'role': _currentUser!.role.name});
    return _currentUser!;
  }

  /// Refresh the current token.
  Future<void> refreshToken() async {
    if (_currentToken == null) throw StateError('No token to refresh');
    AppLogger.log(LogLevel.info, 'AuthService.refreshToken');
    final result = await _apiClient.refreshToken();
    _currentToken = result['token'] as String;
    _currentUser = User.fromJson(result['user'] as Map<String, dynamic>);
    await _storage.saveSecure('auth_token', _currentToken!);
  }

  /// Clear local session.
  Future<void> logout() async {
    AppLogger.log(LogLevel.info, 'AuthService.logout');
    await _apiClient.logout();
    _currentToken = null;
    _currentUser = null;
    await _storage.deleteSecure('auth_token');
    await _storage.clearCache();
  }

  /// Extract claims from the current user.
  Map<String, dynamic> getClaims() {
    return _currentUser?.claims ?? {};
  }

  /// Validate that the current token is still live.
  bool validateToken() {
    if (_currentToken == null) return false;
    return _apiClient.validateToken() != null;
  }

  /// Tenant isolation: ensure the active user belongs to [tenantId].
  bool validateTenantIsolation(String tenantId) {
    return _currentUser?.tenantId == tenantId;
  }

  /// Try to restore session from persisted token.
  Future<bool> tryRestoreSession() async {
    final savedToken = await _storage.readSecure('auth_token');
    if (savedToken == null) return false;

    _apiClient.setAuthToken(savedToken);
    final claims = _apiClient.validateToken();
    if (claims == null) return false;

    _currentToken = savedToken;
    _currentUser = User.fromJson(claims);
    return true;
  }
}
