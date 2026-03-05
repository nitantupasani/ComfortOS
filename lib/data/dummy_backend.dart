import '../domain/models/building.dart';
import '../domain/models/app_config.dart';
import '../domain/models/notification_payload.dart';
import '../platform/logger.dart';

/// In-memory dummy backend simulating the Platform API + Identity Provider.
///
/// External systems (C4):
///   ApiClient → Platform API  (simulated here)
///   AuthService → Identity Provider  (simulated here)
///   Push Provider → NotificationHandler  (simulated here)
class DummyBackend {
  // ── Seed data ──────────────────────────────────────────────────────────

  final Map<String, Map<String, dynamic>> _users = {
    'alice@comfort.io': {
      'id': 'usr-001',
      'email': 'alice@comfort.io',
      'name': 'Alice Occupant',
      'password': 'password',
      'role': 'occupant',
      'tenantId': 'tenant-acme',
      'claims': {
        'scopes': ['vote', 'view_dashboard']
      },
    },
    'bob@comfort.io': {
      'id': 'usr-002',
      'email': 'bob@comfort.io',
      'name': 'Bob Manager',
      'password': 'password',
      'role': 'manager',
      'tenantId': 'tenant-acme',
      'claims': {
        'scopes': ['vote', 'view_dashboard', 'manage_building']
      },
    },
    'admin@comfort.io': {
      'id': 'usr-003',
      'email': 'admin@comfort.io',
      'name': 'Carol Admin',
      'password': 'password',
      'role': 'admin',
      'tenantId': 'tenant-acme',
      'claims': {
        'scopes': ['vote', 'view_dashboard', 'manage_building', 'admin']
      },
    },
  };

  final List<Building> _buildings = const [
    Building(
      id: 'bldg-001',
      name: 'Acme Headquarters',
      address: '123 Innovation Drive',
      tenantId: 'tenant-acme',
      city: 'San Francisco',
      latitude: 37.7749,
      longitude: -122.4194,
      metadata: {'floors': 12, 'zones': 36},
    ),
    Building(
      id: 'bldg-002',
      name: 'Acme Annex',
      address: '456 Oak Avenue',
      tenantId: 'tenant-acme',
      city: 'New York',
      latitude: 40.7128,
      longitude: -74.0060,
      metadata: {'floors': 4, 'zones': 8},
    ),
    Building(
      id: 'bldg-003',
      name: 'GreenTech Research Lab',
      address: '789 Sustainability Blvd',
      tenantId: 'tenant-acme',
      city: 'Portland',
      latitude: 45.5152,
      longitude: -122.6784,
      metadata: {'floors': 3, 'zones': 12},
    ),
    Building(
      id: 'bldg-004',
      name: 'Acme Co-Working Hub',
      address: '21 Startup Lane',
      tenantId: 'tenant-acme',
      city: 'Austin',
      latitude: 30.2672,
      longitude: -97.7431,
      metadata: {'floors': 2, 'zones': 6},
    ),
    Building(
      id: 'bldg-005',
      name: 'Acme Wellness Centre',
      address: '55 Harmony Road',
      tenantId: 'tenant-acme',
      city: 'Denver',
      latitude: 39.7392,
      longitude: -104.9903,
      metadata: {'floors': 5, 'zones': 15},
    ),
  ];

  final List<Map<String, dynamic>> _submittedVotes = [];

  int _tokenCounter = 0;
  final Map<String, String> _activeTokens = {}; // token → email

  // ── Simulated network latency ─────────────────────────────────────────

  Future<T> _simulateLatency<T>(T result) async {
    await Future.delayed(const Duration(milliseconds: 80));
    return result;
  }

  // ── Identity Provider endpoints ───────────────────────────────────────

  /// Login → returns JWT-like token + user payload.
  Future<Map<String, dynamic>> login(String email, String password) async {
    AppLogger.log(LogLevel.info, 'DummyBackend.login($email)');
    final record = _users[email];
    if (record == null || record['password'] != password) {
      throw BackendException(401, 'Invalid credentials');
    }
    _tokenCounter++;
    final token = 'tok_${_tokenCounter}_${DateTime.now().millisecondsSinceEpoch}';
    _activeTokens[token] = email;

    final userMap = Map<String, dynamic>.from(record)..remove('password');
    return _simulateLatency({'token': token, 'user': userMap});
  }

  /// Refresh token.
  Future<Map<String, dynamic>> refreshToken(String currentToken) async {
    final email = _activeTokens[currentToken];
    if (email == null) throw BackendException(401, 'Token expired');

    _activeTokens.remove(currentToken);
    _tokenCounter++;
    final newToken = 'tok_${_tokenCounter}_${DateTime.now().millisecondsSinceEpoch}';
    _activeTokens[newToken] = email;

    final userMap = Map<String, dynamic>.from(_users[email]!)..remove('password');
    return _simulateLatency({'token': newToken, 'user': userMap});
  }

  /// Validate a token and resolve claims.
  Map<String, dynamic>? validateToken(String token) {
    final email = _activeTokens[token];
    if (email == null) return null;
    final userMap = Map<String, dynamic>.from(_users[email]!)..remove('password');
    return userMap;
  }

  /// Logout.
  Future<void> logout(String token) async {
    _activeTokens.remove(token);
  }

  // ── Platform API endpoints ────────────────────────────────────────────

  Future<List<Building>> getBuildings(String tenantId) async {
    final filtered = _buildings.where((b) => b.tenantId == tenantId).toList();
    return _simulateLatency(filtered);
  }

  /// Returns SDUI dashboard config for a building.
  /// Each building demonstrates a different dashboard style.
  /// Returns null for unknown buildings → triggers default dashboard fallback.
  Future<Map<String, dynamic>?> getDashboardConfig(String buildingId) async {
    final configs = <String, Map<String, dynamic>>{
      // ───────────────────────────────────────────────────────────────────
      // bldg-001: CORPORATE HQ – classic comfort-metrics dashboard
      // Weather badge, 3 metric tiles, temperature trend, HVAC alert.
      // ───────────────────────────────────────────────────────────────────
      'bldg-001': {
        'type': 'column',
        'crossAxisAlignment': 'stretch',
        'children': [
          {
            'type': 'weather_badge',
            'temp': '15',
            'unit': '°C',
            'label': 'Outside',
            'icon': 'wb_sunny',
          },
          {'type': 'spacer', 'height': 8},
          {'type': 'room_selector', 'room': 'Conference Room A'},
          {'type': 'spacer', 'height': 16},
          {
            'type': 'grid',
            'columns': 3,
            'spacing': 10,
            'children': [
              {
                'type': 'metric_tile',
                'icon': 'thermostat',
                'value': '22.5',
                'unit': '°C',
                'label': 'Temp',
              },
              {
                'type': 'metric_tile',
                'icon': 'co2',
                'value': '820',
                'unit': 'ppm',
                'label': 'CO2',
              },
              {
                'type': 'metric_tile',
                'icon': 'volume_up',
                'value': '45',
                'unit': 'dB',
                'label': 'Noise',
              },
            ],
          },
          {'type': 'spacer', 'height': 16},
          {
            'type': 'trend_card',
            'title': 'Temperature Trend',
            'subtitle': 'Last 24 hours',
            'change': '+1.2°',
            'data': [15.0, 15.0, 18.0, 22.0, 25.0, 22.5],
            'labels': ['12AM', '6AM', '12PM', '6PM'],
          },
          {'type': 'spacer', 'height': 16},
          {
            'type': 'alert_banner',
            'icon': 'thermostat',
            'title': 'Building is Warming Up',
            'subtitle':
                'HVAC system is adjusting to reach target temperature.',
            'color': 'orange',
          },
        ],
      },

      // ───────────────────────────────────────────────────────────────────
      // bldg-002: SMALL ANNEX – minimal dashboard, fewer metrics, no trend
      // Uses null → causes DefaultDashboard fallback (kept intentionally)
      // ───────────────────────────────────────────────────────────────────
      // (bldg-002 omitted → returns null → DefaultDashboard used)

      // ───────────────────────────────────────────────────────────────────
      // bldg-003: RESEARCH LAB – energy / sustainability focused
      // KPI cards, progress bars for energy & air quality, schedule.
      // ───────────────────────────────────────────────────────────────────
      'bldg-003': {
        'type': 'column',
        'crossAxisAlignment': 'stretch',
        'children': [
          {
            'type': 'weather_badge',
            'temp': '9',
            'unit': '°C',
            'label': 'Outside',
            'icon': 'cloud',
          },
          {'type': 'spacer', 'height': 12},

          // Hero banner
          {
            'type': 'image_banner',
            'title': 'Sustainability Dashboard',
            'subtitle': 'Real-time energy & environment',
            'icon': 'eco',
            'color': 'green',
          },
          {'type': 'spacer', 'height': 16},

          // Section: Energy
          {'type': 'section_header', 'title': 'Energy Usage', 'icon': 'bolt'},
          {'type': 'spacer', 'height': 8},
          {
            'type': 'grid',
            'columns': 2,
            'spacing': 10,
            'children': [
              {
                'type': 'kpi_card',
                'title': 'Solar Generation',
                'value': '42',
                'unit': ' kW',
                'trend': 'up',
                'color': 'green',
              },
              {
                'type': 'kpi_card',
                'title': 'Grid Consumption',
                'value': '118',
                'unit': ' kW',
                'trend': 'down',
                'color': 'orange',
              },
            ],
          },
          {'type': 'spacer', 'height': 12},
          {
            'type': 'progress_bar',
            'label': 'Renewable share',
            'value': 26.2,
            'max': 100,
            'unit': '%',
            'color': 'green',
          },
          {
            'type': 'progress_bar',
            'label': 'Battery storage',
            'value': 73,
            'max': 100,
            'unit': '%',
            'color': 'blue',
          },
          {'type': 'spacer', 'height': 20},

          // Section: Environment metrics
          {
            'type': 'section_header',
            'title': 'Lab Environment',
            'icon': 'science',
          },
          {'type': 'spacer', 'height': 8},
          {
            'type': 'grid',
            'columns': 3,
            'spacing': 10,
            'children': [
              {
                'type': 'metric_tile',
                'icon': 'thermostat',
                'value': '21.0',
                'unit': '°C',
                'label': 'Temp',
              },
              {
                'type': 'metric_tile',
                'icon': 'opacity',
                'value': '55',
                'unit': '%',
                'label': 'Humidity',
              },
              {
                'type': 'metric_tile',
                'icon': 'air',
                'value': '12',
                'unit': 'µg/m³',
                'label': 'PM2.5',
              },
            ],
          },
          {'type': 'spacer', 'height': 12},
          {
            'type': 'trend_card',
            'title': 'CO₂ Trend',
            'subtitle': 'Last 12 hours',
            'change': '-45ppm',
            'data': [680, 720, 750, 710, 680, 650],
            'labels': ['6AM', '9AM', '12PM', '3PM'],
          },
          {'type': 'spacer', 'height': 16},

          // Badges
          {
            'type': 'badge_row',
            'badges': [
              {'label': 'LEED Platinum', 'icon': 'verified', 'color': 'green'},
              {'label': 'Net Zero Target', 'icon': 'eco', 'color': 'teal'},
              {
                'label': 'ISO 50001',
                'icon': 'energy_savings_leaf',
                'color': 'blue',
              },
            ],
          },
          {'type': 'spacer', 'height': 16},

          {
            'type': 'alert_banner',
            'icon': 'eco',
            'title': 'Carbon-neutral today',
            'subtitle':
                'Solar + REC offsets exceed consumption for the day.',
            'color': 'green',
          },
        ],
      },

      // ───────────────────────────────────────────────────────────────────
      // bldg-004: CO-WORKING HUB – occupancy-focused, social dashboard
      // Occupancy ring, schedule, badge row, stat rows.
      // ───────────────────────────────────────────────────────────────────
      'bldg-004': {
        'type': 'column',
        'crossAxisAlignment': 'stretch',
        'children': [
          {
            'type': 'weather_badge',
            'temp': '29',
            'unit': '°C',
            'label': 'Outside',
            'icon': 'wb_sunny',
          },
          {'type': 'spacer', 'height': 12},

          // Occupancy + comfort side by side
          {
            'type': 'grid',
            'columns': 2,
            'spacing': 10,
            'children': [
              {
                'type': 'occupancy_indicator',
                'label': 'Space Occupancy',
                'percent': 73,
                'color': 'orange',
              },
              {
                'type': 'kpi_card',
                'title': 'Comfort Score',
                'value': '8.4',
                'unit': '/10',
                'trend': 'up',
                'color': 'green',
              },
            ],
          },
          {'type': 'spacer', 'height': 16},

          // Section: Quick stats
          {
            'type': 'section_header',
            'title': 'Quick Stats',
            'icon': 'speed',
          },
          {'type': 'spacer', 'height': 6},
          {
            'type': 'stat_row',
            'icon': 'thermostat',
            'label': 'Temperature',
            'value': '24.1 °C',
          },
          {
            'type': 'stat_row',
            'icon': 'opacity',
            'label': 'Humidity',
            'value': '48%',
          },
          {
            'type': 'stat_row',
            'icon': 'volume_up',
            'label': 'Noise Level',
            'value': '52 dB',
            'color': 'orange',
          },
          {
            'type': 'stat_row',
            'icon': 'light',
            'label': 'Lighting',
            'value': '420 lux',
          },
          {
            'type': 'stat_row',
            'icon': 'wifi',
            'label': 'WiFi Signal',
            'value': 'Strong',
            'color': 'green',
          },
          {'type': 'spacer', 'height': 20},

          // Section: Today's schedule
          {
            'type': 'section_header',
            'title': "Today's Schedule",
            'icon': 'schedule',
          },
          {'type': 'spacer', 'height': 8},
          {
            'type': 'schedule_item',
            'time': '09:00',
            'title': 'Morning standup',
            'subtitle': 'Hot Desk Zone A',
            'icon': 'people',
            'active': true,
          },
          {
            'type': 'schedule_item',
            'time': '11:30',
            'title': 'Workshop: Flutter UI',
            'subtitle': 'Meeting Room 2',
            'icon': 'event',
          },
          {
            'type': 'schedule_item',
            'time': '14:00',
            'title': 'Quiet Focus Time',
            'subtitle': 'Phone Booth 3',
            'icon': 'timer',
          },
          {'type': 'spacer', 'height': 16},

          // Amenity badges
          {
            'type': 'badge_row',
            'badges': [
              {'label': 'Free Coffee', 'icon': 'restaurant', 'color': 'brown'},
              {'label': 'Parking', 'icon': 'local_parking', 'color': 'blue'},
              {'label': 'Gym', 'icon': 'fitness_center', 'color': 'purple'},
            ],
          },
          {'type': 'spacer', 'height': 16},

          {
            'type': 'alert_banner',
            'icon': 'campaign',
            'title': 'Community Event at 5 PM',
            'subtitle': 'Rooftop networking mixer — all members welcome.',
            'color': 'blue',
          },
        ],
      },

      // ───────────────────────────────────────────────────────────────────
      // bldg-005: WELLNESS CENTRE – health & wellbeing focused
      // Air quality progress bars, wellness metrics, alert.
      // ───────────────────────────────────────────────────────────────────
      'bldg-005': {
        'type': 'column',
        'crossAxisAlignment': 'stretch',
        'children': [
          {
            'type': 'weather_badge',
            'temp': '5',
            'unit': '°C',
            'label': 'Outside',
            'icon': 'ac_unit',
          },
          {'type': 'spacer', 'height': 12},

          {
            'type': 'image_banner',
            'title': 'Wellness Dashboard',
            'subtitle': 'Your health-aware environment',
            'icon': 'health_and_safety',
            'color': 'teal',
          },
          {'type': 'spacer', 'height': 16},

          // Wellness KPIs
          {
            'type': 'grid',
            'columns': 2,
            'spacing': 10,
            'children': [
              {
                'type': 'kpi_card',
                'title': 'Wellbeing Index',
                'value': '92',
                'unit': '%',
                'trend': 'up',
                'color': 'teal',
              },
              {
                'type': 'kpi_card',
                'title': 'Air Quality Index',
                'value': '38',
                'unit': ' AQI',
                'color': 'green',
              },
            ],
          },
          {'type': 'spacer', 'height': 16},

          // Section: Air Quality breakdown
          {
            'type': 'section_header',
            'title': 'Air Quality Breakdown',
            'icon': 'air',
          },
          {'type': 'spacer', 'height': 8},
          {
            'type': 'progress_bar',
            'label': 'PM2.5',
            'value': 8,
            'max': 50,
            'unit': ' µg/m³',
            'color': 'green',
          },
          {
            'type': 'progress_bar',
            'label': 'PM10',
            'value': 18,
            'max': 100,
            'unit': ' µg/m³',
            'color': 'green',
          },
          {
            'type': 'progress_bar',
            'label': 'TVOC',
            'value': 220,
            'max': 500,
            'unit': ' ppb',
            'color': 'blue',
          },
          {
            'type': 'progress_bar',
            'label': 'CO₂',
            'value': 480,
            'max': 1000,
            'unit': ' ppm',
            'color': 'green',
          },
          {'type': 'spacer', 'height': 18},

          // Comfort metrics
          {
            'type': 'section_header',
            'title': 'Comfort Metrics',
            'icon': 'monitor_heart',
          },
          {'type': 'spacer', 'height': 8},
          {
            'type': 'grid',
            'columns': 3,
            'spacing': 10,
            'children': [
              {
                'type': 'metric_tile',
                'icon': 'thermostat',
                'value': '23.0',
                'unit': '°C',
                'label': 'Temp',
              },
              {
                'type': 'metric_tile',
                'icon': 'opacity',
                'value': '50',
                'unit': '%',
                'label': 'Humidity',
              },
              {
                'type': 'metric_tile',
                'icon': 'tungsten',
                'value': '500',
                'unit': 'lux',
                'label': 'Light',
              },
            ],
          },
          {'type': 'spacer', 'height': 16},

          {
            'type': 'trend_card',
            'title': 'Indoor Air Quality',
            'subtitle': 'AQI over 24 hours',
            'data': [42, 40, 38, 35, 38, 38],
            'labels': ['12AM', '6AM', '12PM', '6PM'],
          },
          {'type': 'spacer', 'height': 16},

          // Info rows
          {
            'type': 'section_header',
            'title': 'Building Details',
            'icon': 'info',
          },
          {'type': 'spacer', 'height': 6},
          {
            'type': 'info_row',
            'icon': 'cleaning_services',
            'label': 'Last cleaned',
            'value': '08:30 AM today',
          },
          {
            'type': 'info_row',
            'icon': 'security',
            'label': 'Safety check',
            'value': 'Passed ✓',
          },
          {
            'type': 'info_row',
            'icon': 'update',
            'label': 'HVAC filter',
            'value': 'Changed 3 days ago',
          },
          {'type': 'spacer', 'height': 16},

          {
            'type': 'badge_row',
            'badges': [
              {'label': 'WELL Certified', 'icon': 'health_and_safety', 'color': 'teal'},
              {'label': 'Low VOC', 'icon': 'air', 'color': 'green'},
              {'label': 'Circadian Lighting', 'icon': 'lightbulb', 'color': 'amber'},
            ],
          },
          {'type': 'spacer', 'height': 16},

          {
            'type': 'alert_banner',
            'icon': 'health_and_safety',
            'title': 'Excellent Air Quality',
            'subtitle':
                'All pollutant levels well within safe limits.',
            'color': 'green',
          },
        ],
      },
    };

    return _simulateLatency(configs[buildingId]);
  }

  /// Returns vote form schema for building – each building has a distinct form
  /// tailored by its facility manager.
  Future<Map<String, dynamic>?> getVoteFormConfig(String buildingId) async {
    final configs = <String, Map<String, dynamic>>{
      // ── bldg-001 : Acme HQ – standard thermal comfort form ──────────
      'bldg-001': {
        'schemaVersion': 2,
        'formTitle': 'Comfort Vote',
        'formDescription':
            'Quick 1-minute survey about your office environment.',
        'thanksMessage': 'Thanks for your feedback!',
        'allowAnonymous': false,
        'cooldownMinutes': 30,
        'fields': [
          {
            'key': 'thermal_comfort',
            'type': 'thermal_scale',
            'question': 'How hot or cold do you feel?',
            'min': 1,
            'max': 7,
            'defaultValue': 4,
            'labels': {
              '1': 'Cold',
              '4': 'Neutral',
              '7': 'Hot',
            },
          },
          {
            'key': 'thermal_preference',
            'type': 'single_select',
            'question': 'Do you want to be warmer or cooler?',
            'options': [
              {
                'label': 'Warmer',
                'value': 1,
                'color': 'orange',
                'emoji': '🔥'
              },
              {
                'label': 'I am good',
                'value': 2,
                'color': 'green',
                'emoji': '👍'
              },
              {
                'label': 'Cooler',
                'value': 3,
                'color': 'blue',
                'emoji': '❄️'
              },
            ],
          },
          {
            'key': 'air_quality',
            'type': 'multi_select',
            'question': 'What do you think about the air quality?',
            'options': [
              {'label': 'Suffocating', 'value': 'suffocating', 'emoji': '😤'},
              {'label': 'Humid', 'value': 'humid', 'emoji': '💧'},
              {'label': 'Dry', 'value': 'dry', 'emoji': '🏜️'},
              {'label': 'Smelly', 'value': 'smelly', 'emoji': '🤢'},
              {
                'label': 'All good!',
                'value': 'all_good',
                'exclusive': true,
                'color': 'green',
                'emoji': '✅',
              },
            ],
          },
        ],
      },

      // ── bldg-003 : GreenTech Research Lab – energy & environment focus ──
      'bldg-003': {
        'schemaVersion': 2,
        'formTitle': 'Lab Environment Check',
        'formDescription':
            'Help us optimize the lab environment for your research.',
        'thanksMessage': 'Your input keeps the lab running efficiently!',
        'allowAnonymous': true,
        'cooldownMinutes': 60,
        'fields': [
          {
            'key': 'overall_comfort',
            'type': 'emoji_scale',
            'question': 'How comfortable is the lab right now?',
            'options': [
              {'emoji': '🥶', 'value': 1, 'label': 'Freezing'},
              {'emoji': '😬', 'value': 2, 'label': 'Chilly'},
              {'emoji': '😊', 'value': 3, 'label': 'Just Right'},
              {'emoji': '😓', 'value': 4, 'label': 'Warm'},
              {'emoji': '🥵', 'value': 5, 'label': 'Too Hot'},
            ],
          },
          {
            'key': 'ventilation',
            'type': 'emoji_single_select',
            'question': 'How is the air ventilation?',
            'options': [
              {
                'emoji': '💨',
                'label': 'Too Drafty',
                'value': 1,
                'color': 'blue'
              },
              {
                'emoji': '🌬️',
                'label': 'Good Airflow',
                'value': 2,
                'color': 'green'
              },
              {
                'emoji': '😶‍🌫️',
                'label': 'Stuffy',
                'value': 3,
                'color': 'orange'
              },
            ],
          },
          {
            'key': 'lighting',
            'type': 'rating_stars',
            'question': 'Rate the lighting quality for lab work',
            'max': 5,
            'color': 'amber',
          },
          {
            'key': 'fume_hood',
            'type': 'yes_no',
            'question': 'Is the fume hood operating properly?',
            'yesLabel': 'Yes',
            'noLabel': 'No',
            'yesEmoji': '✅',
            'noEmoji': '⚠️',
          },
          {
            'key': 'comments',
            'type': 'text_input',
            'question': 'Any notes for the lab manager?',
            'hint': 'E.g., equipment noise, temperature swings…',
            'maxLength': 300,
            'required': false,
          },
        ],
      },

      // ── bldg-004 : Acme Co-Working Hub – social / amenity focus ──────
      'bldg-004': {
        'schemaVersion': 2,
        'formTitle': 'Space Vibe Check 💬',
        'formDescription': 'Tell us how this co-working space feels today.',
        'thanksMessage': 'Awesome, thanks for sharing! 🎉',
        'allowAnonymous': true,
        'cooldownMinutes': 15,
        'fields': [
          {
            'key': 'overall_mood',
            'type': 'emoji_scale',
            'question': 'How\'s the vibe right now?',
            'options': [
              {'emoji': '😞', 'value': 1, 'label': 'Bad'},
              {'emoji': '😐', 'value': 2, 'label': 'Meh'},
              {'emoji': '🙂', 'value': 3, 'label': 'OK'},
              {'emoji': '😄', 'value': 4, 'label': 'Good'},
              {'emoji': '🤩', 'value': 5, 'label': 'Amazing'},
            ],
          },
          {
            'key': 'noise_level',
            'type': 'emoji_single_select',
            'question': 'Noise level?',
            'options': [
              {
                'emoji': '🤫',
                'label': 'Too Quiet',
                'value': 1,
                'color': 'blue'
              },
              {
                'emoji': '👌',
                'label': 'Just Right',
                'value': 2,
                'color': 'green'
              },
              {
                'emoji': '📢',
                'label': 'Too Loud',
                'value': 3,
                'color': 'red'
              },
            ],
          },
          {
            'key': 'amenities',
            'type': 'emoji_multi_select',
            'question': 'Which amenities are you enjoying?',
            'options': [
              {'emoji': '☕', 'value': 'coffee', 'label': 'Coffee'},
              {'emoji': '🍕', 'value': 'food', 'label': 'Snacks'},
              {'emoji': '📶', 'value': 'wifi', 'label': 'WiFi'},
              {'emoji': '🪴', 'value': 'plants', 'label': 'Plants'},
              {'emoji': '🎵', 'value': 'music', 'label': 'Music'},
            ],
          },
          {
            'key': 'recommend_rating',
            'type': 'rating_stars',
            'question': 'Would you recommend this space to a friend?',
            'max': 5,
            'color': 'amber',
          },
        ],
      },

      // ── bldg-005 : Acme Wellness Centre – health & air quality focus ─
      'bldg-005': {
        'schemaVersion': 2,
        'formTitle': 'Wellness Environment Survey',
        'formDescription':
            'Your feedback helps us maintain the healthiest possible environment.',
        'thanksMessage': 'Thank you for prioritizing your wellness! 🌿',
        'allowAnonymous': false,
        'cooldownMinutes': 45,
        'fields': [
          {
            'key': 'breathing_comfort',
            'type': 'emoji_scale',
            'question': 'How easy is it to breathe?',
            'options': [
              {'emoji': '😵', 'value': 1, 'label': 'Terrible'},
              {'emoji': '😟', 'value': 2, 'label': 'Poor'},
              {'emoji': '😐', 'value': 3, 'label': 'OK'},
              {'emoji': '😊', 'value': 4, 'label': 'Good'},
              {'emoji': '🌬️', 'value': 5, 'label': 'Fresh'},
            ],
          },
          {
            'key': 'thermal_comfort',
            'type': 'thermal_scale',
            'question': 'How hot or cold do you feel?',
            'min': 1,
            'max': 7,
            'defaultValue': 4,
            'labels': {
              '1': 'Cold',
              '4': 'Neutral',
              '7': 'Hot',
            },
          },
          {
            'key': 'scent',
            'type': 'yes_no',
            'question':
                'Can you smell any unpleasant odors?',
            'yesLabel': 'Yes 😷',
            'noLabel': 'No 😌',
          },
          {
            'key': 'symptoms',
            'type': 'multi_select',
            'question': 'Are you experiencing any of these?',
            'options': [
              {
                'label': 'Headache',
                'value': 'headache',
                'emoji': '🤕'
              },
              {
                'label': 'Dry eyes',
                'value': 'dry_eyes',
                'emoji': '👁️'
              },
              {
                'label': 'Fatigue',
                'value': 'fatigue',
                'emoji': '😴'
              },
              {
                'label': 'Congestion',
                'value': 'congestion',
                'emoji': '🤧'
              },
              {
                'label': 'None',
                'value': 'none',
                'exclusive': true,
                'color': 'green',
                'emoji': '💪',
              },
            ],
          },
          {
            'key': 'wellness_rating',
            'type': 'rating_stars',
            'question': 'Rate the overall environment for wellness activities',
            'max': 5,
            'color': 'green',
          },
          {
            'key': 'feedback',
            'type': 'text_input',
            'question': 'Any additional wellness feedback?',
            'hint': 'E.g., lighting too bright in yoga room, music too loud…',
            'maxLength': 400,
            'required': false,
          },
        ],
      },
    };

    // bldg-002 returns null → app falls back to DefaultVoteForm
    return _simulateLatency(configs[buildingId]);
  }

  /// Submit a vote. Returns confirmation. Idempotent by voteUuid.
  Future<Map<String, dynamic>> submitVote(Map<String, dynamic> voteData) async {
    final uuid = voteData['voteUuid'] as String;
    // Idempotent: if we already have this UUID, return success without dupe.
    final existing = _submittedVotes.where((v) => v['voteUuid'] == uuid);
    if (existing.isNotEmpty) {
      return _simulateLatency({
        'status': 'already_accepted',
        'voteUuid': uuid,
      });
    }
    // Store with the final confirmed status so history reflects the real outcome.
    final confirmed = Map<String, dynamic>.from(voteData)
      ..['status'] = 'confirmed';
    _submittedVotes.add(confirmed);
    return _simulateLatency({
      'status': 'accepted',
      'voteUuid': uuid,
    });
  }

  /// Get vote history for a user.
  Future<List<Map<String, dynamic>>> getVoteHistory(String userId) async {
    final userVotes =
        _submittedVotes.where((v) => v['userId'] == userId).toList();
    return _simulateLatency(userVotes);
  }

  /// App config (schema version etc.).
  Future<AppConfig> getAppConfig(String buildingId) async {
    final dashboard = await getDashboardConfig(buildingId);
    final form = await getVoteFormConfig(buildingId);
    return AppConfig(
      schemaVersion: 1,
      dashboardLayout: dashboard,
      voteFormSchema: form,
      fetchedAt: DateTime.now(),
    );
  }

  /// Returns SDUI location form config for a building.
  /// For bldg-001: structured floor/room dropdowns.
  /// For bldg-002: null → location screen shows manual entry.
  Future<Map<String, dynamic>?> getLocationFormConfig(
      String buildingId) async {
    final configs = <String, Map<String, dynamic>>{
      'bldg-001': {
        'floors': [
          {'value': '1', 'label': 'Ground Floor'},
          {'value': '2', 'label': 'First Floor'},
          {'value': '3', 'label': 'Second Floor'},
          {'value': '4', 'label': 'Third Floor'},
        ],
        'rooms': {
          '1': [
            {'value': 'reception', 'label': 'Reception'},
            {'value': 'lobby', 'label': 'Lobby'},
            {'value': 'cafeteria', 'label': 'Cafeteria'},
          ],
          '2': [
            {'value': 'conf-a', 'label': 'Conference Room A'},
            {'value': 'conf-b', 'label': 'Conference Room B'},
            {'value': 'open-office-2', 'label': 'Open Office'},
          ],
          '3': [
            {'value': 'lab-1', 'label': 'Research Lab 1'},
            {'value': 'lab-2', 'label': 'Research Lab 2'},
            {'value': 'quiet-zone', 'label': 'Quiet Zone'},
          ],
          '4': [
            {'value': 'exec-suite', 'label': 'Executive Suite'},
            {'value': 'board-room', 'label': 'Board Room'},
            {'value': 'roof-garden', 'label': 'Roof Garden Lounge'},
          ],
        },
      },
      'bldg-003': {
        'floors': [
          {'value': '1', 'label': 'Ground Floor'},
          {'value': '2', 'label': 'Lab Floor'},
          {'value': '3', 'label': 'Clean Room Floor'},
        ],
        'rooms': {
          '1': [
            {'value': 'atrium', 'label': 'Atrium'},
            {'value': 'workshop', 'label': 'Maker Workshop'},
          ],
          '2': [
            {'value': 'chem-lab', 'label': 'Chemistry Lab'},
            {'value': 'bio-lab', 'label': 'Biology Lab'},
            {'value': 'shared-instruments', 'label': 'Shared Instruments'},
          ],
          '3': [
            {'value': 'clean-room-a', 'label': 'Clean Room A'},
            {'value': 'clean-room-b', 'label': 'Clean Room B'},
          ],
        },
      },
      'bldg-004': {
        'floors': [
          {'value': '1', 'label': 'Ground Floor'},
          {'value': '2', 'label': 'Upper Floor'},
        ],
        'rooms': {
          '1': [
            {'value': 'hot-desk-a', 'label': 'Hot Desk Zone A'},
            {'value': 'meeting-1', 'label': 'Meeting Room 1'},
            {'value': 'phone-booth-1', 'label': 'Phone Booth 1'},
            {'value': 'kitchen', 'label': 'Kitchen & Lounge'},
          ],
          '2': [
            {'value': 'hot-desk-b', 'label': 'Hot Desk Zone B'},
            {'value': 'meeting-2', 'label': 'Meeting Room 2'},
            {'value': 'phone-booth-2', 'label': 'Phone Booth 2'},
            {'value': 'phone-booth-3', 'label': 'Phone Booth 3'},
            {'value': 'rooftop', 'label': 'Rooftop Terrace'},
          ],
        },
      },
      'bldg-005': {
        'floors': [
          {'value': '1', 'label': 'Reception'},
          {'value': '2', 'label': 'Fitness Floor'},
          {'value': '3', 'label': 'Spa Floor'},
          {'value': '4', 'label': 'Consultation'},
          {'value': '5', 'label': 'Meditation Floor'},
        ],
        'rooms': {
          '1': [
            {'value': 'front-desk', 'label': 'Front Desk'},
            {'value': 'juice-bar', 'label': 'Juice Bar'},
          ],
          '2': [
            {'value': 'gym-main', 'label': 'Main Gym'},
            {'value': 'yoga-studio', 'label': 'Yoga Studio'},
            {'value': 'cycle-room', 'label': 'Cycle Room'},
          ],
          '3': [
            {'value': 'sauna', 'label': 'Sauna'},
            {'value': 'pool', 'label': 'Pool Area'},
            {'value': 'treatment-1', 'label': 'Treatment Room 1'},
          ],
          '4': [
            {'value': 'consult-a', 'label': 'Consultation A'},
            {'value': 'consult-b', 'label': 'Consultation B'},
          ],
          '5': [
            {'value': 'meditation-hall', 'label': 'Meditation Hall'},
            {'value': 'zen-garden', 'label': 'Zen Garden'},
          ],
        },
      },
    };

    return _simulateLatency(configs[buildingId]);
  }

  // ── Push simulation ───────────────────────────────────────────────────

  /// Simulate an incoming push (call after vote confirmation, config change, etc.)
  NotificationPayload simulatePush({
    required NotificationType type,
    required String title,
    required String body,
    String? deepLink,
    Map<String, dynamic>? data,
  }) {
    return NotificationPayload(
      id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      title: title,
      body: body,
      deepLink: deepLink,
      data: data,
      receivedAt: DateTime.now(),
    );
  }
}

/// Typed backend error.
class BackendException implements Exception {
  final int statusCode;
  final String message;
  const BackendException(this.statusCode, this.message);

  @override
  String toString() => 'BackendException($statusCode): $message';
}
