import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bustracking/models/bus.dart';
import 'package:bustracking/models/stop.dart';
import 'package:bustracking/models/live_location.dart';
import 'package:bustracking/services/api_service.dart';
import 'package:bustracking/services/cache_service.dart';

import 'package:bustracking/services/connectivity_service.dart';

import 'package:bustracking/services/location_service.dart';

// Service providers
final cacheServiceProvider = Provider<CacheService>((ref) {
  return CacheService();
});

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(() => service.dispose());
  return service;
});

final apiServiceProvider = Provider<ApiService>((ref) {
  final cache = ref.watch(cacheServiceProvider);
  final connectivity = ref.watch(connectivityServiceProvider);
  return ApiService(cache, connectivity);
});



final locationServiceProvider = Provider<LocationService>((ref) {
  final loc = LocationService();
  ref.onDispose(() => loc.dispose());
  return loc;
});

// App State Providers
final busesProvider = FutureProvider<List<Bus>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getBuses();
});

final selectedBusIdProvider = StateProvider<int?>((ref) => null);

final selectedBusStopsProvider = FutureProvider<List<Stop>>((ref) async {
  final busId = ref.watch(selectedBusIdProvider);
  if (busId == null) return [];
  final api = ref.watch(apiServiceProvider);
  return api.getStops(busId);
});

// Connectivity state stream provider
final connectivityStreamProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.connectivityStream;
});

// Driver Tracking State
final driverTrackingActiveProvider = StateProvider<bool>((ref) => false);
final driverSimulationActiveProvider = StateProvider<bool>((ref) => false);

// Telemetry stream from GPS/Sim for the Driver Dashboard
final driverLocationStreamProvider = StreamProvider.autoDispose<SimPosition>((ref) {
  final locationService = ref.watch(locationServiceProvider);
  return locationService.positionStream;
});

// Student Live Location Stream via polling
final liveLocationProvider = StreamProvider.autoDispose.family<LiveLocation?, int>((ref, busId) async* {
  final api = ref.watch(apiServiceProvider);
  while (true) {
    final loc = await api.getLiveLocation(busId);
    if (loc != null) {
      yield loc;
    }
    await Future.delayed(const Duration(seconds: 5));
  }
});

// Live WebSocket connection status provider
final wsStatusProvider = StreamProvider.autoDispose<WsStatus>((ref) => Stream.value(WsStatus.connected));
