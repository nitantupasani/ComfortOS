/// Aggregate comfort data for a building, broken down by location.
///
/// Returned by the Platform API and rendered on the Building Comfort screen.
/// When no location breakdown is available the list contains a single entry
/// for the whole building.
class BuildingComfortData {
  final String buildingId;
  final String buildingName;
  final double overallScore; // 0.0 – 10.0
  final int totalVotes;
  final DateTime computedAt;
  final List<LocationComfortData> locations;
  final Map<String, dynamic>? sduiConfig; // optional SDUI override

  const BuildingComfortData({
    required this.buildingId,
    required this.buildingName,
    required this.overallScore,
    required this.totalVotes,
    required this.computedAt,
    this.locations = const [],
    this.sduiConfig,
  });

  factory BuildingComfortData.fromJson(Map<String, dynamic> json) {
    return BuildingComfortData(
      buildingId: json['buildingId'] as String,
      buildingName: json['buildingName'] as String,
      overallScore: (json['overallScore'] as num).toDouble(),
      totalVotes: json['totalVotes'] as int,
      computedAt: DateTime.parse(json['computedAt'] as String),
      locations: (json['locations'] as List<dynamic>?)
              ?.map((e) =>
                  LocationComfortData.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      sduiConfig: json['sduiConfig'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'buildingId': buildingId,
        'buildingName': buildingName,
        'overallScore': overallScore,
        'totalVotes': totalVotes,
        'computedAt': computedAt.toIso8601String(),
        'locations': locations.map((l) => l.toJson()).toList(),
        if (sduiConfig != null) 'sduiConfig': sduiConfig,
      };
}

/// Comfort aggregation for a single floor + room combination.
class LocationComfortData {
  final String floor;
  final String floorLabel;
  final String? room;
  final String? roomLabel;
  final double comfortScore; // 0.0 – 10.0
  final int voteCount;
  final Map<String, double> breakdown; // e.g. {'thermal': 7.2, 'air': 8.1}

  const LocationComfortData({
    required this.floor,
    required this.floorLabel,
    this.room,
    this.roomLabel,
    required this.comfortScore,
    required this.voteCount,
    this.breakdown = const {},
  });

  factory LocationComfortData.fromJson(Map<String, dynamic> json) {
    return LocationComfortData(
      floor: json['floor'] as String,
      floorLabel: json['floorLabel'] as String,
      room: json['room'] as String?,
      roomLabel: json['roomLabel'] as String?,
      comfortScore: (json['comfortScore'] as num).toDouble(),
      voteCount: json['voteCount'] as int,
      breakdown: (json['breakdown'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ??
          const {},
    );
  }

  Map<String, dynamic> toJson() => {
        'floor': floor,
        'floorLabel': floorLabel,
        if (room != null) 'room': room,
        if (roomLabel != null) 'roomLabel': roomLabel,
        'comfortScore': comfortScore,
        'voteCount': voteCount,
        'breakdown': breakdown,
      };
}
