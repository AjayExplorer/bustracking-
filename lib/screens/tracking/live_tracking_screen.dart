import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:bustracking/core/constants.dart';
import 'package:bustracking/models/stop.dart';
import 'package:bustracking/models/live_location.dart';
import 'package:bustracking/providers/bus_provider.dart';
import 'package:bustracking/services/route_tracker.dart';
import 'package:bustracking/widgets/route_info_panel.dart';

class LiveTrackingScreen extends ConsumerStatefulWidget {
  final int busId;
  const LiveTrackingScreen({super.key, required this.busId});

  @override
  ConsumerState<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends ConsumerState<LiveTrackingScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  AnimationController? _animationController;

  // Marker state
  List<Marker> _stopMarkers = [];
  Marker? _busMarker;
  bool _markersInitialized = false;

  // Interpolated location state
  LatLng? _prevLatLng;
  LatLng? _targetLatLng;
  LatLng? _currentLatLng;
  double _currentSpeed = 0.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    );
    _animationController!.addListener(_animateLocation);
  }

  void _animateLocation() {
    if (_prevLatLng != null && _targetLatLng != null) {
      final t = _animationController!.value;
      final lat = _prevLatLng!.latitude + (_targetLatLng!.latitude - _prevLatLng!.latitude) * t;
      final lng = _prevLatLng!.longitude + (_targetLatLng!.longitude - _prevLatLng!.longitude) * t;
      setState(() {
        _currentLatLng = LatLng(lat, lng);
      });
    }
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  Future<void> _initMarkers(List<Stop> stops) async {
    final List<Marker> markers = [];
    for (int i = 0; i < stops.length; i++) {
      final stop = stops[i];
      Color color = AppConstants.primaryColor;
      String label = (i + 1).toString();
      if (i == 0) {
        color = AppConstants.success;
        label = 'S';
      } else if (i == stops.length - 1) {
        color = AppConstants.danger;
        label = 'D';
      }
      markers.add(Marker(
        width: 40,
        height: 40,
        point: LatLng(stop.latitude, stop.longitude),
        builder: (ctx) => Container(
          alignment: Alignment.center,
          child: Icon(Icons.location_on, color: color, size: 30),
        ),
      ));
    }
    setState(() {
      _stopMarkers = markers;
      _markersInitialized = true;
    });
  }

  void _onLocationUpdate(LiveLocation location) {
    final newLatLng = LatLng(location.latitude, location.longitude);
    _currentSpeed = location.speed;
    if (_targetLatLng == null) {
      setState(() {
        _targetLatLng = newLatLng;
        _currentLatLng = newLatLng;
      });
      _mapController.move(newLatLng, 14.0);
    } else {
      _prevLatLng = _currentLatLng;
      _targetLatLng = newLatLng;
      _animationController!.forward(from: 0.0);
    }
    // Update bus marker
    setState(() {
      _busMarker = Marker(
        width: 40,
        height: 40,
        point: newLatLng,
        builder: (ctx) => const Icon(Icons.directions_bus, color: Colors.blue, size: 30),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final stopsAsync = ref.watch(selectedBusStopsProvider);
    final liveLocationAsync = ref.watch(liveLocationProvider(widget.busId));

    // Initialize markers when stops are ready
    stopsAsync.whenData((stops) {
      if (!_markersInitialized && stops.isNotEmpty) {
        _initMarkers(stops);
      }
    });

    // Listen to live location updates
    ref.listen<AsyncValue<LiveLocation?>>(liveLocationProvider(widget.busId), (prev, next) {
      next.whenData((loc) {
        if (loc != null) _onLocationUpdate(loc);
      });
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Live Tracking')),
      body: stopsAsync.when(
        data: (stops) {
          if (stops.isEmpty) return const Center(child: Text('No route stops defined for this bus.'));
          final polylinePoints = stops.map((s) => LatLng(s.latitude, s.longitude)).toList();

          // Compute stats (same as previous logic)
          Map<String, dynamic> stats = {
            'currentStop': null,
            'nextStop': stops.first,
            'distanceRemaining': 0.0,
            'distanceToNext': 0.0,
            'status': 'Not Started',
            'segmentIndex': -1,
          };
          if (_currentLatLng != null) {
            final busLat = _currentLatLng!.latitude;
            final busLng = _currentLatLng!.longitude;
            final stopsInfo = RouteTracker.determineStops(busLat: busLat, busLng: busLng, stops: stops);
            final currentStop = stopsInfo['currentStop'] as Stop?;
            final nextStop = stopsInfo['nextStop'] as Stop?;
            final segmentIndex = stopsInfo['segmentIndex'] as int;
            final projectionFactor = stopsInfo['projectionFactor'] as double;
            final distRemaining = RouteTracker.calculateRemainingDistance(
              busLat: busLat,
              busLng: busLng,
              stops: stops,
              segmentIndex: segmentIndex,
              projectionFactor: projectionFactor,
            );
            double distToNext = 0.0;
            if (nextStop != null) {
              distToNext = Geolocator.distanceBetween(busLat, busLng, nextStop.latitude, nextStop.longitude);
            }
            final busStatus = RouteTracker.determineBusStatus(
              busLat: busLat,
              busLng: busLng,
              stops: stops,
              speed: _currentSpeed,
              segmentIndex: segmentIndex,
              projectionFactor: projectionFactor,
            );
            stats = {
              'currentStop': currentStop,
              'nextStop': nextStop,
              'distanceRemaining': distRemaining,
              'distanceToNext': distToNext,
              'status': busStatus,
              'segmentIndex': segmentIndex,
            };
          }

          // Combine markers
          final List<Marker> allMarkers = List.from(_stopMarkers);
          if (_busMarker != null) allMarkers.add(_busMarker!);

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  center: LatLng(stops.first.latitude, stops.first.longitude),
                  zoom: 12.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: polylinePoints,
                        color: AppConstants.primaryColor.withValues(alpha: 0.8),
                        strokeWidth: 6.0,
                      ),
                    ],
                  ),
                  MarkerLayer(markers: allMarkers),
                ],
              ),
              // Connection status pill (always connected for now)
              Positioned(
                top: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppConstants.darkCard.withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppConstants.success.withValues(alpha: 0.3), width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.cloud_done_rounded, color: AppConstants.success, size: 16),
                        SizedBox(width: 8),
                        Text('Live Connected', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppConstants.success)),
                      ],
                    ),
                  ),
                ),
              ),
              // Route info panel
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: RouteInfoPanel(
                  busName: 'Bus A',
                  currentStop: stats['currentStop'] as Stop?,
                  nextStop: stats['nextStop'] as Stop?,
                  destinationStop: stops.last,
                  distanceRemaining: stats['distanceRemaining'] as double,
                  distanceToNext: stats['distanceToNext'] as double,
                  speed: _currentSpeed,
                  status: stats['status'] as String,
                  stops: stops,
                  segmentIndex: stats['segmentIndex'] as int,
                ),
              ),
              // Loading overlay
              if (_currentLatLng == null)
                Container(
                  color: Colors.black.withValues(alpha: 0.4),
                  child: Center(
                    child: Card(
                      color: isDark ? AppConstants.darkCard : Colors.white,
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            CircularProgressIndicator(),
                            SizedBox(height: 20),
                            Text('Waiting for bus coordinates...', style: TextStyle(fontWeight: FontWeight.bold)),
                            SizedBox(height: 8),
                            Text('Please ensure the driver has started tracking.', textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error loading stops: $err', style: const TextStyle(color: AppConstants.danger)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: () => ref.invalidate(selectedBusStopsProvider), child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}
