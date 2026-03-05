import 'dart:convert';
import 'package:http/http.dart' as http;

import '../domain/models/weather_data.dart';
import '../platform/logger.dart';

/// Service that fetches **real-time** weather from the free Open-Meteo API.
///
/// No API key required. Docs: https://open-meteo.com/en/docs
///
/// Features:
/// - Location is resolved from the building's latitude/longitude stored in the
///   database, so every building automatically gets weather for its own city.
/// - In-memory caching (15-minute TTL) prevents redundant API calls during
///   normal navigation; callers can pass [forceRefresh] to bypass the cache
///   (e.g. when the user taps the refresh button).
/// - **Per-user API rate limiting**: each user ID is allowed at most
///   [maxRequestsPerUser] calls within [rateLimitWindow]. Once the limit is
///   reached the service returns the cached (possibly stale) value and logs a
///   warning, rather than making another network call.
class WeatherService {
  WeatherService();

  // ── Cache ─────────────────────────────────────────────────────────────

  final Map<String, WeatherData> _cache = {};
  final Map<String, DateTime> _cacheTs = {};
  static const _cacheTtl = Duration(minutes: 15);

  // ── Per-user API rate limiting ────────────────────────────────────────

  /// Maximum number of weather API requests a single user may trigger within
  /// [rateLimitWindow]. Adjust to stay within Open-Meteo's free tier
  /// (10 000 req/day) while supporting multiple concurrent users.
  static const int maxRequestsPerUser = 30;

  /// Sliding window over which [maxRequestsPerUser] is enforced.
  static const Duration rateLimitWindow = Duration(hours: 1);

  /// userId → list of timestamps of past requests.
  final Map<String, List<DateTime>> _userRequestLog = {};

  /// Check whether [userId] has exceeded the per-user rate limit.
  /// Also prunes expired entries from the log.
  bool _isRateLimited(String userId) {
    final now = DateTime.now();
    final log = _userRequestLog.putIfAbsent(userId, () => []);
    // Remove entries outside the sliding window.
    log.removeWhere((ts) => now.difference(ts) > rateLimitWindow);
    return log.length >= maxRequestsPerUser;
  }

  /// Record a successful API call for [userId].
  void _recordRequest(String userId) {
    _userRequestLog.putIfAbsent(userId, () => []).add(DateTime.now());
  }

  /// Returns how many API calls [userId] has remaining in the current window.
  int remainingQuota(String userId) {
    final now = DateTime.now();
    final log = _userRequestLog[userId];
    if (log == null) return maxRequestsPerUser;
    log.removeWhere((ts) => now.difference(ts) > rateLimitWindow);
    return (maxRequestsPerUser - log.length).clamp(0, maxRequestsPerUser);
  }

  // ── Public API ────────────────────────────────────────────────────────

  /// Fetch current weather for the given coordinates (from the building record
  /// in the database).
  ///
  /// - [userId]: the logged-in user's ID, used for per-user rate limiting.
  /// - [forceRefresh]: when `true` the in-memory cache is bypassed so the user
  ///   sees up-to-date weather (intended for the refresh button). The API rate
  ///   limit still applies.
  ///
  /// Returns cached result if still fresh (<15 min) and [forceRefresh] is
  /// `false`. Returns `null` on any network or parsing error so the UI can
  /// gracefully fall back.
  Future<WeatherData?> fetchWeather({
    required double latitude,
    required double longitude,
    required String userId,
    bool forceRefresh = false,
  }) async {
    final cacheKey =
        '${latitude.toStringAsFixed(2)}_${longitude.toStringAsFixed(2)}';

    final cached = _cache[cacheKey];
    final ts = _cacheTs[cacheKey];

    // Return cache hit if still fresh and not forcing refresh.
    if (!forceRefresh &&
        cached != null &&
        ts != null &&
        DateTime.now().difference(ts) < _cacheTtl) {
      return cached;
    }

    // ── Per-user rate limit check ──
    if (_isRateLimited(userId)) {
      AppLogger.log(LogLevel.warning,
          'WeatherService: rate limit reached for user $userId '
          '($maxRequestsPerUser requests / ${rateLimitWindow.inMinutes} min)');
      return cached; // return stale cache rather than making another call
    }

    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$latitude'
        '&longitude=$longitude'
        '&current=temperature_2m,relative_humidity_2m,apparent_temperature,wind_speed_10m,weather_code'
        '&timezone=auto',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      // Record the network call regardless of HTTP status.
      _recordRequest(userId);

      if (response.statusCode != 200) {
        AppLogger.log(LogLevel.warning,
            'WeatherService: HTTP ${response.statusCode}');
        return cached; // return stale cache on failure
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final current = json['current'] as Map<String, dynamic>;

      final code = (current['weather_code'] as num).toInt();
      final desc = WeatherData.describeWeatherCode(code);

      final data = WeatherData(
        temperature: (current['temperature_2m'] as num).toDouble(),
        feelsLike: (current['apparent_temperature'] as num).toDouble(),
        humidity: (current['relative_humidity_2m'] as num).toInt(),
        windSpeed: (current['wind_speed_10m'] as num).toDouble(),
        weatherCode: code,
        description: desc.description,
        icon: desc.icon,
        fetchedAt: DateTime.now(),
      );

      // Update cache.
      _cache[cacheKey] = data;
      _cacheTs[cacheKey] = DateTime.now();

      AppLogger.log(LogLevel.info,
          'WeatherService: ${data.temperature}°C ${data.description} '
          '(remaining quota for $userId: ${remainingQuota(userId)})');
      return data;
    } catch (e) {
      AppLogger.log(LogLevel.warning, 'WeatherService: $e');
      return cached; // return stale cache on error
    }
  }

  /// Invalidate the weather cache entirely (e.g. on building switch).
  void clearCache() {
    _cache.clear();
    _cacheTs.clear();
  }

  /// Invalidate the cache for a specific coordinate pair so the next
  /// [fetchWeather] call makes a fresh API request.
  void clearCacheForLocation(double latitude, double longitude) {
    final key =
        '${latitude.toStringAsFixed(2)}_${longitude.toStringAsFixed(2)}';
    _cache.remove(key);
    _cacheTs.remove(key);
  }
}
