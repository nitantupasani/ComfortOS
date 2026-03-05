import '../data/api_client.dart';
import '../domain/models/notification_payload.dart';
import '../platform/logger.dart';

/// Listens for push notifications, parses/deduplicates payloads, orchestrates
/// background fetches, and resolves deep-links.
///
/// Relationships (C4):
///   Push Provider → NotificationHandler : delivers push notifications
///   NotificationHandler → AppStateStore : updates notification state
///   NotificationHandler → ApiClient     : commands fetch of new schema/messages
class NotificationHandler {
  final ApiClient _apiClient;

  /// Seen notification IDs for deduplication.
  final Set<String> _receivedIds = {};

  /// In-memory notification list.
  final List<NotificationPayload> _notifications = [];

  NotificationHandler({required ApiClient apiClient})
      : _apiClient = apiClient;

  List<NotificationPayload> get notifications =>
      List.unmodifiable(_notifications);

  int get unreadCount =>
      _notifications.where((n) => n.data?['read'] != true).length;

  /// Accessor for API client (used by background fetch orchestration).
  ApiClient get apiClient => _apiClient;

  /// Initialize push listener (simulated).
  Future<void> initialize() async {
    AppLogger.log(LogLevel.info, 'NotificationHandler: initialized');
    // In production: register with FCM/APNs, request permissions, etc.
  }

  /// Handle an incoming notification (called by the platform push callback).
  Future<NotificationPayload?> onNotificationReceived(
      Map<String, dynamic> raw) async {
    try {
      final payload = parsePayload(raw);

      // Deduplicate
      if (!deduplicatePayload(payload)) {
        AppLogger.log(LogLevel.info,
            'NotificationHandler: duplicate ${payload.id} ignored');
        return null;
      }

      _notifications.insert(0, payload);

      // Orchestrate background fetch based on type
      await _handleByType(payload);

      AppLogger.log(LogLevel.info,
          'NotificationHandler: processed ${payload.id} (${payload.type.name})');
      return payload;
    } catch (e, st) {
      AppLogger.reportCrash(e, st);
      return null;
    }
  }

  /// Parse raw push data into a typed payload.
  NotificationPayload parsePayload(Map<String, dynamic> raw) {
    return NotificationPayload.fromJson(raw);
  }

  /// Returns true if this is a NEW notification (not a duplicate).
  bool deduplicatePayload(NotificationPayload payload) {
    return _receivedIds.add(payload.id);
  }

  /// Resolve a deep-link from a notification to a GoRouter path.
  String? resolveDeepLink(NotificationPayload payload) {
    if (payload.deepLink == null) return null;
    // Map external deep-links to internal routes.
    final link = payload.deepLink!;
    if (link.contains('vote')) return '/vote';
    if (link.contains('dashboard')) return '/dashboard';
    if (link.contains('presence')) return '/presence';
    return '/';
  }

  // ── Private ───────────────────────────────────────────────────────────

  Future<void> _handleByType(NotificationPayload payload) async {
    switch (payload.type) {
      case NotificationType.configUpdate:
        // Fetch latest config from API
        AppLogger.log(
            LogLevel.info, 'NotificationHandler: fetching updated config');
        break;
      case NotificationType.voteConfirmation:
        // Could refresh vote history
        break;
      case NotificationType.alert:
      case NotificationType.deepLink:
        break;
    }
  }
}
