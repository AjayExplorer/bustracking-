class LiveLocation {
  final int id;
  final int busId;
  final double latitude;
  final double longitude;
  final double speed;
  final DateTime updatedAt;

  LiveLocation({
    required this.id,
    required this.busId,
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.updatedAt,
  });

  factory LiveLocation.fromJson(Map<String, dynamic> json) {
    return LiveLocation(
      id: json['id'] is int ? json['id'] as int : 0,
      busId: json['bus_id'] ?? json['busId'] as int,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      speed: (json['speed'] as num).toDouble(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String)
          : json['updatedAt'] != null 
              ? DateTime.parse(json['updatedAt'] as String)
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bus_id': busId,
      'latitude': latitude,
      'longitude': longitude,
      'speed': speed,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
