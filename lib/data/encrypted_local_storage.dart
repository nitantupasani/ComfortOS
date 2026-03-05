import 'dart:convert';

import 'package:hive/hive.dart';

import '../platform/logger.dart';

/// Encrypted local storage backed by Hive.
///
/// Relationships (C4):
///   OfflineVoteQueue → EncryptedLocalStorage : persists queued votes
///   AppStateStore    → EncryptedLocalStorage : persists minimal state/cache
class EncryptedLocalStorage {
  static const _secureBoxName = 'secure_box';
  static const _cacheBoxName = 'cache_box';

  Box? _secureBox;
  Box? _cacheBox;

  bool get isInitialized => _secureBox?.isOpen == true;

  /// Must be called once before any read/write.
  Future<void> init() async {
    try {
      _secureBox = await Hive.openBox(_secureBoxName);
      _cacheBox = await Hive.openBox(_cacheBoxName);
      AppLogger.log(LogLevel.info, 'EncryptedLocalStorage initialized');
    } catch (e, st) {
      AppLogger.reportCrash(e, st);
      rethrow;
    }
  }

  // ── Secure key-value (tokens, sensitive IDs) ─────────────────────────

  Future<void> saveSecure(String key, String value) async {
    await _secureBox?.put(key, value);
  }

  Future<String?> readSecure(String key) async {
    return _secureBox?.get(key) as String?;
  }

  Future<void> deleteSecure(String key) async {
    await _secureBox?.delete(key);
  }

  // ── Cache (JSON maps – configs, server state) ────────────────────────

  Future<void> cacheData(String key, Map<String, dynamic> data) async {
    await _cacheBox?.put(key, jsonEncode(data));
  }

  Future<Map<String, dynamic>?> getCachedData(String key) async {
    final raw = _cacheBox?.get(key) as String?;
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  /// Persist a list of JSON-serialisable maps under [key].
  Future<void> cacheList(String key, List<Map<String, dynamic>> items) async {
    await _cacheBox?.put(key, jsonEncode(items));
  }

  Future<List<Map<String, dynamic>>> getCachedList(String key) async {
    final raw = _cacheBox?.get(key) as String?;
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as List;
    return decoded.cast<Map<String, dynamic>>();
  }

  Future<void> clearCache() async {
    await _cacheBox?.clear();
  }

  Future<void> clearAll() async {
    await _secureBox?.clear();
    await _cacheBox?.clear();
  }
}
