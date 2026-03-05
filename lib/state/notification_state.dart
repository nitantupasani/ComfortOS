import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/notification_payload.dart';
import '../services/notification_handler.dart';

/// Notification list/state.
class NotificationState {
  final List<NotificationPayload> notifications;
  final String? pendingDeepLink;

  const NotificationState({
    this.notifications = const [],
    this.pendingDeepLink,
  });

  int get unreadCount => notifications.length;

  NotificationState copyWith({
    List<NotificationPayload>? notifications,
    String? pendingDeepLink,
  }) =>
      NotificationState(
        notifications: notifications ?? this.notifications,
        pendingDeepLink: pendingDeepLink,
      );
}

/// Notifier owning notification state.
///
/// Relationships (C4):
///   NotificationHandler → AppStateStore : updates notification state; routes deep-links
class NotificationNotifier extends StateNotifier<NotificationState> {
  final NotificationHandler _handler;

  NotificationNotifier(this._handler) : super(const NotificationState());

  /// Initialise push listeners.
  Future<void> init() async {
    await _handler.initialize();
  }

  /// Simulate receiving a notification (use from dummy backend or testing).
  Future<void> receive(Map<String, dynamic> raw) async {
    final payload = await _handler.onNotificationReceived(raw);
    if (payload != null) {
      final deepLink = _handler.resolveDeepLink(payload);
      state = state.copyWith(
        notifications: _handler.notifications,
        pendingDeepLink: deepLink,
      );
    }
  }

  /// Consume the pending deep-link (router calls this after navigating).
  void consumeDeepLink() {
    state = state.copyWith(pendingDeepLink: null);
  }
}
