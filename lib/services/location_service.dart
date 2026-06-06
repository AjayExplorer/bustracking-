import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class SimPosition {
  final double latitude;
  final double longitude;
  final double speed;
  final DateTime timestamp;

  SimPosition({
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.timestamp,
  });
}

class LocationService {
  StreamSubscription<Position>? _gpsSubscription;
  Timer? _simulationTimer;
  final _positionController = StreamController<SimPosition>.broadcast();
  
  bool _isSimulating = false;
  int _simulationIndex = 0;
  List<SimPosition> _simulatedPoints = [];

  LocationService() {
    _generateSimulationPoints();
  }

  Stream<SimPosition> get positionStream => _positionController.stream;
  bool get isSimulating => _isSimulating;

  // Predefined route stops coordinates
  static const List<Map<String, dynamic>> routeStops = [
    {'name': 'Kottayam', 'lat': 9.5869, 'lng': 76.5213},
    {'name': 'Kumaranalloor', 'lat': 9.6185, 'lng': 76.5310},
    {'name': 'Sankranthi', 'lat': 9.6250, 'lng': 76.5383},
    {'name': 'Ettumanoor', 'lat': 9.6704, 'lng': 76.5609},
    {'name': 'Peroor', 'lat': 9.6503, 'lng': 76.5639},
    {'name': 'Kidangoor', 'lat': 9.6667, 'lng': 76.6000},
    {'name': 'Pala', 'lat': 9.7138, 'lng': 76.6829},
  ];

  // Interpolates between predefined stops to generate a smooth series of GPS coordinates
  void _generateSimulationPoints() {
    final List<SimPosition> points = [];
    const double speedMps = 10.0; // 36 km/h simulation speed
    
    for (int i = 0; i < routeStops.length - 1; i++) {
      final start = routeStops[i];
      final end = routeStops[i + 1];

      final double startLat = start['lat'] as double;
      final double startLng = start['lng'] as double;
      final double endLat = end['lat'] as double;
      final double endLng = end['lng'] as double;

      final double distance = Geolocator.distanceBetween(
        startLat, startLng, endLat, endLng
      );

      // In 5 seconds, at 10m/s, the bus travels 50 meters
      final int steps = (distance / 50.0).ceil();
      
      for (int step = 0; step < steps; step++) {
        final double t = step / steps;
        final double lat = startLat + (endLat - startLat) * t;
        final double lng = startLng + (endLng - startLng) * t;
        
        points.add(SimPosition(
          latitude: lat,
          longitude: lng,
          speed: speedMps,
          timestamp: DateTime.now(),
        ));
      }
    }
    
    // Add destination
    final dest = routeStops.last;
    points.add(SimPosition(
      latitude: dest['lat'] as double,
      longitude: dest['lng'] as double,
      speed: 0.0,
      timestamp: DateTime.now(),
    ));

    _simulatedPoints = points;
  }

  // Requests location permission
  Future<bool> checkPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  // Starts tracking (either via hardware GPS or Simulation)
  Future<void> startTracking({required bool simulate}) async {
    stopTracking();
    _isSimulating = simulate;

    if (simulate) {
      _simulationIndex = 0;
      _simulationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (_simulationIndex < _simulatedPoints.length) {
          final point = _simulatedPoints[_simulationIndex];
          _positionController.add(SimPosition(
            latitude: point.latitude,
            longitude: point.longitude,
            speed: point.speed,
            timestamp: DateTime.now(),
          ));
          _simulationIndex++;
        } else {
          // Reached destination, hold the last spot with 0 speed
          final lastPoint = _simulatedPoints.last;
          _positionController.add(SimPosition(
            latitude: lastPoint.latitude,
            longitude: lastPoint.longitude,
            speed: 0.0,
            timestamp: DateTime.now(),
          ));
        }
      });
      
      // Emit the first point immediately
      if (_simulatedPoints.isNotEmpty) {
        final point = _simulatedPoints[0];
        _positionController.add(SimPosition(
          latitude: point.latitude,
          longitude: point.longitude,
          speed: point.speed,
          timestamp: DateTime.now(),
        ));
        _simulationIndex = 1;
      }
    } else {
      final hasPermission = await checkPermission();
      if (!hasPermission) {
        throw Exception("GPS Permission denied");
      }

      const LocationSettings settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 2,
      );

      // Create a throttle of 5 seconds to prevent spamming updates
      DateTime? lastUpdateTime;

      _gpsSubscription = Geolocator.getPositionStream(locationSettings: settings).listen(
        (Position position) {
          final now = DateTime.now();
          if (lastUpdateTime == null || now.difference(lastUpdateTime!) >= const Duration(seconds: 4)) {
            lastUpdateTime = now;
            _positionController.add(SimPosition(
              latitude: position.latitude,
              longitude: position.longitude,
              speed: position.speed,
              timestamp: position.timestamp,
            ));
          }
        },
        onError: (e) {
          debugPrint("GPS stream error: $e");
        }
      );
    }
  }

  // Stops tracking
  void stopTracking() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
    _gpsSubscription?.cancel();
    _gpsSubscription = null;
    _isSimulating = false;
  }

  void dispose() {
    stopTracking();
    _positionController.close();
  }
}
