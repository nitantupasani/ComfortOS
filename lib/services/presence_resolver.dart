import '../data/api_client.dart';
import '../domain/models/presence_info.dart';
import '../platform/logger.dart';

/// Hybrid presence resolver combining QR, WiFi, BLE scanning and manual
/// override with confidence scoring.
///
/// Relationships (C4):
///   UI → PresenceResolver : resolves current building context
class PresenceResolver {
  final ApiClient _apiClient;

  PresenceInfo? _currentPresence;
  PresenceInfo? get currentPresence => _currentPresence;

  /// Pre-seeded known buildings (in a real app these come from local beacons DB).
  final Map<String, String> _wifiSsidToBuilding = {
    'AcmeHQ-5G': 'bldg-001',
    'AcmeHQ-Guest': 'bldg-001',
    'AcmeAnnex-WiFi': 'bldg-002',
  };

  final Map<String, String> _bleBeaconToBuilding = {
    'beacon-001-a': 'bldg-001',
    'beacon-002-a': 'bldg-002',
  };

  PresenceResolver({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Accessor for API client (used for beacon DB fetches in production).
  ApiClient get apiClient => _apiClient;

  /// Attempt all detection methods and pick the highest-confidence result.
  Future<PresenceInfo?> resolvePresence() async {
    final results = <PresenceInfo>[];

    final wifi = await checkWiFi();
    if (wifi != null) results.add(wifi);

    final ble = await checkBLE();
    if (ble != null) results.add(ble);

    if (results.isEmpty) return _currentPresence;

    // Pick highest confidence
    results.sort((a, b) => b.confidence.compareTo(a.confidence));
    _currentPresence = results.first;
    return _currentPresence;
  }

  /// Simulate scanning a QR code that encodes a building ID.
  Future<PresenceInfo> scanQR(String qrPayload) async {
    AppLogger.log(LogLevel.info, 'PresenceResolver.scanQR($qrPayload)');
    // QR payload is the building ID directly.
    _currentPresence = PresenceInfo(
      buildingId: qrPayload,
      method: PresenceMethod.qr,
      confidence: 1.0,
      timestamp: DateTime.now(),
      isVerified: true,
    );
    return _currentPresence!;
  }

  /// Simulate WiFi-based presence detection.
  Future<PresenceInfo?> checkWiFi() async {
    await Future.delayed(const Duration(milliseconds: 100));
    // Simulate detecting "AcmeHQ-5G"
    const detectedSsid = 'AcmeHQ-5G';
    final buildingId = _wifiSsidToBuilding[detectedSsid];
    if (buildingId == null) return null;
    return PresenceInfo(
      buildingId: buildingId,
      method: PresenceMethod.wifi,
      confidence: 0.75,
      timestamp: DateTime.now(),
    );
  }

  /// Simulate BLE beacon–based presence detection.
  Future<PresenceInfo?> checkBLE() async {
    await Future.delayed(const Duration(milliseconds: 150));
    // Simulate detecting beacon-001-a
    const detectedBeacon = 'beacon-001-a';
    final buildingId = _bleBeaconToBuilding[detectedBeacon];
    if (buildingId == null) return null;
    return PresenceInfo(
      buildingId: buildingId,
      method: PresenceMethod.ble,
      confidence: 0.85,
      timestamp: DateTime.now(),
    );
  }

  /// Manually set the active building (confidence = 0.5, not auto-verified).
  Future<PresenceInfo> manualOverride(String buildingId) async {
    AppLogger.log(
        LogLevel.info, 'PresenceResolver.manualOverride($buildingId)');
    _currentPresence = PresenceInfo(
      buildingId: buildingId,
      method: PresenceMethod.manual,
      confidence: 0.5,
      timestamp: DateTime.now(),
      isVerified: false,
    );
    return _currentPresence!;
  }

  double getConfidenceScore() => _currentPresence?.confidence ?? 0.0;
}
