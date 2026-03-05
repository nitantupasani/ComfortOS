/// Weather conditions for a building location.
class WeatherData {
  final double temperature; // °C
  final double feelsLike; // °C (apparent temperature)
  final int humidity; // %
  final double windSpeed; // km/h
  final int weatherCode; // WMO weather code
  final String description; // human-readable label
  final String icon; // SDUI icon name
  final DateTime fetchedAt;

  const WeatherData({
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.weatherCode,
    required this.description,
    required this.icon,
    required this.fetchedAt,
  });

  /// Round temperature for display.
  String get tempDisplay => '${temperature.round()}';

  /// Map WMO weather code → human-readable description + icon name.
  static ({String description, String icon}) describeWeatherCode(int code) {
    // https://open-meteo.com/en/docs — WMO Weather interpretation codes
    if (code == 0) return (description: 'Clear sky', icon: 'wb_sunny');
    if (code <= 3) return (description: 'Partly cloudy', icon: 'cloud');
    if (code <= 49) return (description: 'Foggy', icon: 'cloud');
    if (code <= 59) return (description: 'Drizzle', icon: 'water_drop');
    if (code <= 69) return (description: 'Rain', icon: 'water_drop');
    if (code <= 79) return (description: 'Snow', icon: 'ac_unit');
    if (code <= 82) return (description: 'Rain showers', icon: 'water_drop');
    if (code <= 86) return (description: 'Snow showers', icon: 'ac_unit');
    if (code == 95) return (description: 'Thunderstorm', icon: 'bolt');
    if (code <= 99) return (description: 'Thunderstorm', icon: 'bolt');
    return (description: 'Unknown', icon: 'cloud');
  }
}
