import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api_client.dart';
import '../data/dummy_backend.dart';
import '../data/encrypted_local_storage.dart';
import '../data/offline_vote_queue.dart';
import '../domain/permissions_engine.dart';
import '../domain/vote_domain.dart';
import '../services/auth_service.dart';
import '../services/config_governance.dart';
import '../services/notification_handler.dart';
import '../services/presence_resolver.dart';
import '../services/sync_worker.dart';
import '../services/weather_service.dart';
import '../domain/models/weather_data.dart';

import 'auth_state.dart';
import 'presence_state.dart';
import 'vote_state.dart';
import 'notification_state.dart';

// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  PROVIDER GRAPH – mirrors every C4 component and its relationships     ║
// ╚══════════════════════════════════════════════════════════════════════════╝

// ── Platform / Infrastructure ───────────────────────────────────────────

/// Encrypted local storage (initialised before runApp and overridden).
final encryptedLocalStorageProvider = Provider<EncryptedLocalStorage>(
  (_) => throw UnimplementedError('Override in main()'),
);

/// In-memory dummy backend replacing external Platform API + Identity Provider.
final dummyBackendProvider = Provider<DummyBackend>((_) => DummyBackend());

// ── Data Access ─────────────────────────────────────────────────────────

final offlineVoteQueueProvider = Provider<OfflineVoteQueue>((ref) {
  return OfflineVoteQueue(ref.read(encryptedLocalStorageProvider));
});

/// API Client – HTTP client abstraction with token injection, rate limiting,
/// and idempotent request handling.
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    backend: ref.read(dummyBackendProvider),
    offlineQueue: ref.read(offlineVoteQueueProvider),
  );
});

// ── Domain ──────────────────────────────────────────────────────────────

final voteDomainProvider = Provider<VoteDomain>((_) => VoteDomain());
final permissionsEngineProvider =
    Provider<PermissionsEngine>((_) => PermissionsEngine());

// ── Services ────────────────────────────────────────────────────────────

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    apiClient: ref.read(apiClientProvider),
    storage: ref.read(encryptedLocalStorageProvider),
  );
});

final presenceResolverProvider = Provider<PresenceResolver>((ref) {
  return PresenceResolver(apiClient: ref.read(apiClientProvider));
});

final configGovernanceProvider = Provider<ConfigGovernance>((ref) {
  return ConfigGovernance(
    apiClient: ref.read(apiClientProvider),
    storage: ref.read(encryptedLocalStorageProvider),
  );
});

final syncWorkerProvider = Provider<SyncWorker>((ref) {
  return SyncWorker(
    queue: ref.read(offlineVoteQueueProvider),
    apiClient: ref.read(apiClientProvider),
  );
});

final notificationHandlerProvider = Provider<NotificationHandler>((ref) {
  return NotificationHandler(apiClient: ref.read(apiClientProvider));
});

// ── State Notifiers ─────────────────────────────────────────────────────

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(authServiceProvider));
});

final presenceStateProvider =
    StateNotifierProvider<PresenceNotifier, PresenceState>((ref) {
  return PresenceNotifier(
    resolver: ref.read(presenceResolverProvider),
    apiClient: ref.read(apiClientProvider),
  );
});

final voteStateProvider =
    StateNotifierProvider<VoteNotifier, VoteState>((ref) {
  return VoteNotifier(
    voteDomain: ref.read(voteDomainProvider),
    apiClient: ref.read(apiClientProvider),
    offlineQueue: ref.read(offlineVoteQueueProvider),
  );
});

final notificationStateProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  return NotificationNotifier(ref.read(notificationHandlerProvider));
});

// ── Derived / Async Providers ───────────────────────────────────────────

/// Dashboard SDUI config for a building (null → use default dashboard).
final dashboardConfigProvider =
    FutureProvider.family<Map<String, dynamic>?, String>(
        (ref, buildingId) async {
  final configGov = ref.read(configGovernanceProvider);
  final config = await configGov.getLatestConfig(buildingId);
  return config?.dashboardLayout;
});

/// Vote form schema for a building.
final voteFormConfigProvider =
    FutureProvider.family<Map<String, dynamic>?, String>(
        (ref, buildingId) async {
  final configGov = ref.read(configGovernanceProvider);
  final config = await configGov.getLatestConfig(buildingId);
  return config?.voteFormSchema;
});

/// Location form schema for a building (floors/rooms).
/// Returns null → location screen falls back to manual entry.
final locationFormConfigProvider =
    FutureProvider.family<Map<String, dynamic>?, String>(
        (ref, buildingId) async {
  if (buildingId.isEmpty) return null;
  final backend = ref.read(dummyBackendProvider);
  return backend.getLocationFormConfig(buildingId);
});

// ── Weather ─────────────────────────────────────────────────────────────

/// Weather service singleton (in-memory caching, Open-Meteo).
final weatherServiceProvider = Provider<WeatherService>((_) => WeatherService());

/// Live weather for the currently active building.
/// Auto-refreshes when the building changes. Returns null on error / no coords.
final weatherProvider = FutureProvider.autoDispose<WeatherData?>((ref) async {
  final presence = ref.watch(presenceStateProvider);
  final building = presence.activeBuilding;
  if (building == null || building.latitude == null || building.longitude == null) {
    return null;
  }
  final service = ref.read(weatherServiceProvider);
  return service.fetchWeather(
    latitude: building.latitude!,
    longitude: building.longitude!,
  );
});
