class Stop {
  final int id;
  final int busId;
  final String stopName;
  final double latitude;
  final double longitude;
  final int stopOrder;

  Stop({
    required this.id,
    required this.busId,
    required this.stopName,
    required this.latitude,
    required this.longitude,
    required this.stopOrder,
  });

  factory Stop.fromJson(Map<String, dynamic> json) {
    return Stop(
      id: json['id'] as int,
      busId: json['bus_id'] as int,
      stopName: json['stop_name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      stopOrder: json['stop_order'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bus_id': busId,
      'stop_name': stopName,
      'latitude': latitude,
      'longitude': longitude,
      'stop_order': stopOrder,
    };
  }
}
