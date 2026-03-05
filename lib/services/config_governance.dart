import '../data/api_client.dart';
import '../data/encrypted_local_storage.dart';
import '../domain/models/app_config.dart';
import '../platform/logger.dart';

/// Schema version tracking and migration compatibility guards.
///
/// Relationships (C4):
///   UI → ConfigGovernance : renders dynamic form via schemaVersion
///   ConfigGovernance keeps track of config versions and ensures
///   backward-compatible migrations.
class ConfigGovernance {
  final ApiClient _apiClient;
  final EncryptedLocalStorage _storage;

  int _currentSchemaVersion = 1;
  AppConfig? _cachedConfig;

  static const _versionKey = 'schema_version';
  static const _configCacheKey = 'app_config';

  ConfigGovernance({
    required ApiClient apiClient,
    required EncryptedLocalStorage storage,
  })  : _apiClient = apiClient,
        _storage = storage;

  int get currentSchemaVersion => _currentSchemaVersion;

  /// Fetch the latest app config for [buildingId] from the API.
  /// Falls back to cached config if the fetch fails.
  Future<AppConfig?> getLatestConfig(String buildingId) async {
    try {
      final config = await _apiClient.getAppConfig(buildingId);

      // Migration compatibility check
      if (!checkMigrationCompatibility(
          _currentSchemaVersion, config.schemaVersion)) {
        AppLogger.log(LogLevel.warning,
            'ConfigGovernance: incompatible schema ${config.schemaVersion}');
        return _cachedConfig; // fall back
      }

      _cachedConfig = config;
      _currentSchemaVersion = config.schemaVersion;
      await _persistVersion();
      await _storage.cacheData(_configCacheKey, config.toJson());
      return config;
    } catch (e, st) {
      AppLogger.reportCrash(e, st);
      // On failure, try local cache
      return _cachedConfig ?? await _restoreFromCache();
    }
  }

  /// Determine whether an upgrade from [from] → [to] is safe.
  bool checkMigrationCompatibility(int from, int to) {
    // Simple rule: allow same version or single-step upgrade.
    return (to - from).abs() <= 1;
  }

  /// Record the current schema version locally.
  Future<void> trackSchemaVersion(int version) async {
    _currentSchemaVersion = version;
    await _persistVersion();
  }

  /// Restore version from storage on app start.
  Future<void> restoreVersion() async {
    final raw = await _storage.readSecure(_versionKey);
    if (raw != null) {
      _currentSchemaVersion = int.tryParse(raw) ?? 1;
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────

  Future<void> _persistVersion() async {
    await _storage.saveSecure(_versionKey, _currentSchemaVersion.toString());
  }

  Future<AppConfig?> _restoreFromCache() async {
    final data = await _storage.getCachedData(_configCacheKey);
    if (data == null) return null;
    return AppConfig.fromJson(data);
  }
}
