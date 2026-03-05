import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/building.dart';
import '../domain/models/presence_info.dart';
import '../data/api_client.dart';
import '../services/presence_resolver.dart';

/// Combined presence + active-building + location state.
class PresenceState {
  final PresenceInfo? presence;
  final Building? activeBuilding;
  final List<Building> availableBuildings;
  final bool isScanning;
  final String? error;
  final String? floor;
  final String? room;

  const PresenceState({
    this.presence,
    this.activeBuilding,
    this.availableBuildings = const [],
    this.isScanning = false,
    this.error,
    this.floor,
    this.room,
  });

  bool get hasLocation => floor != null && room != null;

  PresenceState copyWith({
    PresenceInfo? presence,
    Building? activeBuilding,
    List<Building>? availableBuildings,
    bool? isScanning,
    String? error,
    String? floor,
    String? room,
  }) =>
      PresenceState(
        presence: presence ?? this.presence,
        activeBuilding: activeBuilding ?? this.activeBuilding,
        availableBuildings: availableBuildings ?? this.availableBuildings,
        isScanning: isScanning ?? this.isScanning,
        error: error,
        floor: floor ?? this.floor,
        room: room ?? this.room,
      );
}

/// Notifier owning presence resolution and active building context.
///
/// Relationships (C4):
///   UI → PresenceResolver : resolves current building context
///   AppStateStore : Presence state, Active building
class PresenceNotifier extends StateNotifier<PresenceState> {
  final PresenceResolver _resolver;
  final ApiClient _apiClient;

  PresenceNotifier({
    required PresenceResolver resolver,
    required ApiClient apiClient,
  })  : _resolver = resolver,
        _apiClient = apiClient,
        super(const PresenceState());

  /// Load buildings for the current tenant.
  Future<void> loadBuildings(String tenantId) async {
    try {
      final buildings = await _apiClient.getBuildings(tenantId);
      state = state.copyWith(availableBuildings: buildings);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Run automatic presence detection (WiFi + BLE).
  Future<void> autoDetect() async {
    state = state.copyWith(isScanning: true, error: null);
    try {
      final info = await _resolver.resolvePresence();
      if (info != null) {
        final building = _findBuilding(info.buildingId);
        state = state.copyWith(
          presence: info,
          activeBuilding: building,
          isScanning: false,
        );
      } else {
        state = state.copyWith(isScanning: false);
      }
    } catch (e) {
      state = state.copyWith(isScanning: false, error: e.toString());
    }
  }

  /// Scan a QR code to set presence.
  Future<void> scanQR(String payload) async {
    state = state.copyWith(isScanning: true, error: null);
    try {
      final info = await _resolver.scanQR(payload);
      final building = _findBuilding(info.buildingId);
      state = state.copyWith(
        presence: info,
        activeBuilding: building,
        isScanning: false,
      );
    } catch (e) {
      state = state.copyWith(isScanning: false, error: e.toString());
    }
  }

  /// Manually select a building.
  Future<void> manualSelect(String buildingId) async {
    try {
      final info = await _resolver.manualOverride(buildingId);
      final building = _findBuilding(buildingId);
      state = state.copyWith(presence: info, activeBuilding: building);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Clear active building.
  void clearActiveBuilding() {
    state = const PresenceState();
  }

  /// Set floor and room within the active building.
  void setLocation(String floor, String room) {
    state = state.copyWith(floor: floor, room: room);
  }

  Building? _findBuilding(String? id) {
    if (id == null) return null;
    try {
      return state.availableBuildings.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }
}
