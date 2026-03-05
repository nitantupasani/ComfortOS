import '../domain/models/building.dart';
import '../domain/models/vote.dart';
import '../domain/models/app_config.dart';
import '../platform/logger.dart';
import 'dummy_backend.dart';
import 'offline_vote_queue.dart';

/// HTTP client abstraction with token injection, rate limiting, and
/// idempotent request handling.
///
/// In this implementation, network calls are routed to [DummyBackend].
/// On failure the client automatically enqueues to [OfflineVoteQueue].
///
/// Relationships (C4):
///   ApiClient → Platform API       : fetches config/dashboards; submits votes
///   Auth      → ApiClient          : provides token/claims
///   ApiClient → OfflineVoteQueue   : on network failure, enqueue
///   SyncWorker → ApiClient         : requests upload of queued votes
///   NotificationHandler → ApiClient: commands fetch of new schema/messages
///   AppStateStore → ApiClient      : requests async data fetch
class ApiClient {
  final DummyBackend _backend;
  final OfflineVoteQueue _offlineQueue;

  String? _authToken;
  String? get authToken => _authToken;

  // Rate-limiting state
  final Map<String, DateTime> _lastRequest = {};
  static const _minInterval = Duration(milliseconds: 300);

  // Idempotent-request cache (UUID → response)
  final Map<String, Map<String, dynamic>> _idempotencyCache = {};

  ApiClient({
    required DummyBackend backend,
    required OfflineVoteQueue offlineQueue,
  })  : _backend = backend,
        _offlineQueue = offlineQueue;

  // ── Token injection ───────────────────────────────────────────────────

  void setAuthToken(String? token) {
    _authToken = token;
  }

  void _requireAuth() {
    if (_authToken == null) throw StateError('Not authenticated');
  }

  // ── Rate limiting ────────────────────────────────────────────────────

  Future<void> _rateLimit(String key) async {
    final last = _lastRequest[key];
    if (last != null) {
      final diff = DateTime.now().difference(last);
      if (diff < _minInterval) {
        await Future.delayed(_minInterval - diff);
      }
    }
    _lastRequest[key] = DateTime.now();
  }

  // ── Auth endpoints (delegate to DummyBackend / Identity Provider) ─────

  Future<Map<String, dynamic>> login(String email, String password) async {
    await _rateLimit('login');
    final result = await _backend.login(email, password);
    _authToken = result['token'] as String;
    return result;
  }

  Future<Map<String, dynamic>> refreshToken() async {
    _requireAuth();
    await _rateLimit('refresh');
    final result = await _backend.refreshToken(_authToken!);
    _authToken = result['token'] as String;
    return result;
  }

  Future<void> logout() async {
    if (_authToken != null) {
      await _backend.logout(_authToken!);
    }
    _authToken = null;
  }

  Map<String, dynamic>? validateToken() {
    if (_authToken == null) return null;
    return _backend.validateToken(_authToken!);
  }

  // ── Data endpoints ───────────────────────────────────────────────────

  Future<List<Building>> getBuildings(String tenantId) async {
    _requireAuth();
    await _rateLimit('buildings');
    return _backend.getBuildings(tenantId);
  }

  Future<Map<String, dynamic>?> getDashboardConfig(String buildingId) async {
    _requireAuth();
    await _rateLimit('dashboard_$buildingId');
    return _backend.getDashboardConfig(buildingId);
  }

  Future<Map<String, dynamic>?> getVoteFormConfig(String buildingId) async {
    _requireAuth();
    await _rateLimit('voteform_$buildingId');
    return _backend.getVoteFormConfig(buildingId);
  }

  Future<AppConfig> getAppConfig(String buildingId) async {
    _requireAuth();
    await _rateLimit('config_$buildingId');
    return _backend.getAppConfig(buildingId);
  }

  /// Submit a vote with idempotent request handling.
  /// On failure, automatically enqueues to offline queue.
  Future<Map<String, dynamic>> submitVote(Vote vote) async {
    _requireAuth();

    // Idempotent cache check
    if (_idempotencyCache.containsKey(vote.voteUuid)) {
      AppLogger.log(LogLevel.info,
          'ApiClient: idempotent cache hit for ${vote.voteUuid}');
      return _idempotencyCache[vote.voteUuid]!;
    }

    await _rateLimit('vote_${vote.voteUuid}');
    try {
      final result = await _backend.submitVote(vote.toJson());
      _idempotencyCache[vote.voteUuid] = result;
      return result;
    } catch (e) {
      // On network failure → enqueue for offline sync
      AppLogger.log(LogLevel.warning,
          'ApiClient: submit failed, enqueuing ${vote.voteUuid}');
      await _offlineQueue.enqueue(vote);
      return {'status': 'queued', 'voteUuid': vote.voteUuid};
    }
  }

  Future<List<Map<String, dynamic>>> getVoteHistory(String userId) async {
    _requireAuth();
    await _rateLimit('history_$userId');
    return _backend.getVoteHistory(userId);
  }
}
