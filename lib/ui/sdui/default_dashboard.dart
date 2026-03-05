/// Hardcoded default SDUI dashboard config used when the server returns null.
///
/// Inspired by the dashboard.txt HTML mockup — minimal, clean, mobile-first.
/// Shows: weather badge, room name, 3 metric tiles, temperature trend,
/// HVAC alert banner.
class DefaultDashboard {
  DefaultDashboard._();

  static Map<String, dynamic> get config => {
        'type': 'column',
        'crossAxisAlignment': 'stretch',
        'children': [
          // ── Weather badge ──
          {
            'type': 'weather_badge',
            'temp': '--',
            'unit': '°C',
            'label': 'Outside',
            'icon': 'wb_sunny',
          },

          {'type': 'spacer', 'height': 8},

          // ── Room name ──
          {
            'type': 'room_selector',
            'room': 'No Room Selected',
          },

          {'type': 'spacer', 'height': 16},

          // ── Metric tiles (3 columns) ──
          {
            'type': 'grid',
            'columns': 3,
            'spacing': 10,
            'children': [
              {
                'type': 'metric_tile',
                'icon': 'thermostat',
                'value': '--',
                'unit': '°C',
                'label': 'Temp',
              },
              {
                'type': 'metric_tile',
                'icon': 'co2',
                'value': '--',
                'unit': 'ppm',
                'label': 'CO2',
              },
              {
                'type': 'metric_tile',
                'icon': 'volume_up',
                'value': '--',
                'unit': 'dB',
                'label': 'Noise',
              },
            ],
          },

          {'type': 'spacer', 'height': 16},

          // ── Temperature trend chart ──
          {
            'type': 'trend_card',
            'title': 'Temperature Trend',
            'subtitle': 'Last 24 hours',
            'data': [18, 17, 17, 19, 21, 22],
            'labels': ['12AM', '6AM', '12PM', '6PM'],
          },

          {'type': 'spacer', 'height': 16},

          // ── Alert banner ──
          {
            'type': 'alert_banner',
            'icon': 'info',
            'title': 'No live data',
            'subtitle':
                'Connect to a building to see real-time comfort metrics.',
            'color': 'blue',
          },
        ],
      };
}

