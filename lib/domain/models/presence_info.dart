/// Presence detection result with method and confidence score.
enum PresenceMethod { qr, wifi, ble, manual }

class PresenceInfo {
  final String? buildingId;
  final PresenceMethod method;
  final double confidence; // 0.0 – 1.0
  final DateTime timestamp;
  final bool isVerified;

  const PresenceInfo({
    this.buildingId,
    required this.method,
    required this.confidence,
    required this.timestamp,
    this.isVerified = false,
  });

  PresenceInfo copyWith({
    String? buildingId,
    PresenceMethod? method,
    double? confidence,
    DateTime? timestamp,
    bool? isVerified,
  }) =>
      PresenceInfo(
        buildingId: buildingId ?? this.buildingId,
        method: method ?? this.method,
        confidence: confidence ?? this.confidence,
        timestamp: timestamp ?? this.timestamp,
        isVerified: isVerified ?? this.isVerified,
      );

  Map<String, dynamic> toJson() => {
        'buildingId': buildingId,
        'method': method.name,
        'confidence': confidence,
        'timestamp': timestamp.toIso8601String(),
        'isVerified': isVerified,
      };

  factory PresenceInfo.fromJson(Map<String, dynamic> json) => PresenceInfo(
        buildingId: json['buildingId'] as String?,
        method: PresenceMethod.values.firstWhere(
          (m) => m.name == json['method'],
          orElse: () => PresenceMethod.manual,
        ),
        confidence: (json['confidence'] as num).toDouble(),
        timestamp: DateTime.parse(json['timestamp'] as String),
        isVerified: json['isVerified'] as bool? ?? false,
      );
}
