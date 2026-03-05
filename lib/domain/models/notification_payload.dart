/// Push notification payload with deep-link support.
enum NotificationType { voteConfirmation, configUpdate, alert, deepLink }

class NotificationPayload {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final String? deepLink;
  final Map<String, dynamic>? data;
  final DateTime receivedAt;

  const NotificationPayload({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.deepLink,
    this.data,
    required this.receivedAt,
  });

  factory NotificationPayload.fromJson(Map<String, dynamic> json) {
    return NotificationPayload(
      id: json['id'] as String,
      type: NotificationType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => NotificationType.alert,
      ),
      title: json['title'] as String,
      body: json['body'] as String,
      deepLink: json['deepLink'] as String?,
      data: json['data'] as Map<String, dynamic>?,
      receivedAt: json['receivedAt'] != null
          ? DateTime.parse(json['receivedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'body': body,
        if (deepLink != null) 'deepLink': deepLink,
        if (data != null) 'data': data,
        'receivedAt': receivedAt.toIso8601String(),
      };
}
