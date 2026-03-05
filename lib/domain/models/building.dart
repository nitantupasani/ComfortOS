/// Building model with tenant isolation and geolocation for weather.
class Building {
  final String id;
  final String name;
  final String address;
  final String tenantId;
  final String? city;
  final double? latitude;
  final double? longitude;
  final Map<String, dynamic>? metadata;

  const Building({
    required this.id,
    required this.name,
    required this.address,
    required this.tenantId,
    this.city,
    this.latitude,
    this.longitude,
    this.metadata,
  });

  factory Building.fromJson(Map<String, dynamic> json) {
    return Building(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      tenantId: json['tenantId'] as String,
      city: json['city'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'tenantId': tenantId,
        if (city != null) 'city': city,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (metadata != null) 'metadata': metadata,
      };
}
