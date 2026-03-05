import 'dart:convert';
import 'package:http/http.dart' as http;

import '../domain/models/weather_data.dart';
import '../platform/logger.dart';

/// Service that fetches current weather from the free Open-Meteo API.
///
/// No API key required. Docs: https://open-meteo.com/en/docs
///
/// Includes in-memory caching (15-minute TTL) so we don't hammer the API
/// on every rebuild or navigation.
class WeatherService {
  WeatherService();

  // ── Cache ─────────────────────────────────────────────────────────────

  final Map<String, WeatherData> _cache = {};
  final Map<String, DateTime> _cacheTs = {};
  static const _cacheTtl = Duration(minutes: 15);

  /// Fetch current weather for the given coordinates.
  ///
  /// Returns cached result if still fresh (<15 min). Returns `null` on
  /// any network or parsing error so the UI can gracefully fall back.
  Future<WeatherData?> fetchWeather({
    required double latitude,
    required double longitude,
  }) async {
    final cacheKey = '${latitude.toStringAsFixed(2)}_${longitude.toStringAsFixed(2)}';

    // Return cache hit if still fresh.
    final cached = _cache[cacheKey];
    final ts = _cacheTs[cacheKey];
    if (cached != null && ts != null && DateTime.now().difference(ts) < _cacheTtl) {
      return cached;
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
          'WeatherService: ${data.temperature}°C ${data.description}');
      return data;
    } catch (e) {
      AppLogger.log(LogLevel.warning, 'WeatherService: $e');
      return cached; // return stale cache on error
    }
  }

  /// Invalidate the cache entirely (e.g. on building switch).
  void clearCache() {
    _cache.clear();
    _cacheTs.clear();
  }
}
