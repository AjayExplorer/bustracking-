import 'package:geolocator/geolocator.dart';
import 'package:bustracking/models/stop.dart';

class RouteTracker {
  // Snaps the bus to the closest segment and determines current/next stops
  static Map<String, dynamic> determineStops({
    required double busLat,
    required double busLng,
    required List<Stop> stops,
  }) {
    if (stops.isEmpty) {
      return {
        'currentStop': null,
        'nextStop': null,
        'segmentIndex': -1,
        'projectionFactor': 0.0,
      };
    }
    if (stops.length == 1) {
      return {
        'currentStop': stops.first,
        'nextStop': null,
        'segmentIndex': 0,
        'projectionFactor': 0.0,
      };
    }

    int bestSegmentIndex = 0;
    double minDistance = double.infinity;
    double bestT = 0.0;

    for (int i = 0; i < stops.length - 1; i++) {
      final stopA = stops[i];
      final stopB = stops[i + 1];

      // Math projection using flat coordinates for small distances
      double latA = stopA.latitude;
      double lngA = stopA.longitude;
      double latB = stopB.latitude;
      double lngB = stopB.longitude;

      double dLat = latB - latA;
      double dLng = lngB - lngA;

      double lenSq = dLat * dLat + dLng * dLng;
      double t = 0.0;
      if (lenSq > 0) {
        t = ((busLat - latA) * dLat + (busLng - lngA) * dLng) / lenSq;
        t = t.clamp(0.0, 1.0);
      }

      double projLat = latA + t * dLat;
      double projLng = lngA + t * dLng;

      // Geodesic distance to projected point
      double dist = Geolocator.distanceBetween(busLat, busLng, projLat, projLng);
      if (dist < minDistance) {
        minDistance = dist;
        bestSegmentIndex = i;
        bestT = t;
      }
    }

    final currentStop = stops[bestSegmentIndex];
    final nextStop = stops[bestSegmentIndex + 1];

    return {
      'currentStop': currentStop,
      'nextStop': nextStop,
      'segmentIndex': bestSegmentIndex,
      'projectionFactor': bestT,
    };
  }

  // Calculates remaining distance along the route segments to the destination
  static double calculateRemainingDistance({
    required double busLat,
    required double busLng,
    required List<Stop> stops,
    required int segmentIndex,
    required double projectionFactor,
  }) {
    if (stops.isEmpty || segmentIndex < 0 || segmentIndex >= stops.length - 1) {
      return 0.0;
    }

    final nextStop = stops[segmentIndex + 1];
    
    // 1. Distance from bus to the next stop
    double distToNext = Geolocator.distanceBetween(
      busLat, 
      busLng, 
      nextStop.latitude, 
      nextStop.longitude
    );

    // 2. Sum of distances of all subsequent segments
    double remainingRouteDist = 0.0;
    for (int i = segmentIndex + 1; i < stops.length - 1; i++) {
      final sA = stops[i];
      final sB = stops[i + 1];
      remainingRouteDist += Geolocator.distanceBetween(
        sA.latitude, sA.longitude, sB.latitude, sB.longitude
      );
    }

    return distToNext + remainingRouteDist;
  }

  // Determines the overall bus status
  static String determineBusStatus({
    required double busLat,
    required double busLng,
    required List<Stop> stops,
    required double speed,
    required int segmentIndex,
    required double projectionFactor,
  }) {
    if (stops.isEmpty) return 'Not Started';

    final source = stops.first;
    final destination = stops.last;

    // Check distance to source
    final distToSource = Geolocator.distanceBetween(
      busLat, busLng, source.latitude, source.longitude
    );

    // Check distance to destination
    final distToDest = Geolocator.distanceBetween(
      busLat, busLng, destination.latitude, destination.longitude
    );

    if (distToDest < 100) {
      return 'Reached Destination';
    }

    if (segmentIndex == 0 && projectionFactor < 0.05 && speed < 0.5 && distToSource < 100) {
      return 'Not Started';
    }

    return 'Running';
  }
}
