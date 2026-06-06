import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:bustracking/models/bus.dart';
import 'package:bustracking/models/stop.dart';
import 'package:bustracking/models/live_location.dart';
import 'package:bustracking/services/cache_service.dart';
import 'package:bustracking/services/connectivity_service.dart';

class ApiService {
  final CacheService _cacheService;
  final ConnectivityService _connectivityService;
  
  ApiService(this._cacheService, this._connectivityService);

  String get baseUrl {
    if (kIsWeb) return 'http://localhost:8787';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:8787';
    } catch (_) {}
    return 'http://127.0.0.1:8787';
  }

  Future<List<Bus>> getBuses() async {
    final connected = await _connectivityService.isConnected;
    if (!connected) {
      final cached = await _cacheService.getCachedBuses();
      if (cached != null) return cached;
      throw Exception('Offline and no cached bus data available.');
    }

    try {
      final response = await http.get(Uri.parse('$baseUrl/api/buses'));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as List;
        final list = decoded.map((item) => Bus.fromJson(item as Map<String, dynamic>)).toList();
        await _cacheService.cacheBuses(list);
        return list;
      } else {
        throw Exception('Failed to load buses: ${response.statusCode}');
      }
    } catch (e) {
      final cached = await _cacheService.getCachedBuses();
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<List<Stop>> getStops(int busId) async {
    final connected = await _connectivityService.isConnected;
    if (!connected) {
      final cached = await _cacheService.getCachedStops(busId);
      if (cached != null) return cached;
      throw Exception('Offline and no cached stop data available.');
    }

    try {
      final response = await http.get(Uri.parse('$baseUrl/api/buses/$busId/stops'));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as List;
        final list = decoded.map((item) => Stop.fromJson(item as Map<String, dynamic>)).toList();
        await _cacheService.cacheStops(busId, list);
        return list;
      } else {
        throw Exception('Failed to load stops: ${response.statusCode}');
      }
    } catch (e) {
      final cached = await _cacheService.getCachedStops(busId);
      if (cached != null) return cached;
      rethrow;
    }
  }

  Future<LiveLocation?> getLiveLocation(int busId) async {
    final connected = await _connectivityService.isConnected;
    if (!connected) {
      return await _cacheService.getCachedLiveLocation(busId);
    }

    try {
      final response = await http.get(Uri.parse('$baseUrl/api/location/$busId'));
      if (response.statusCode == 200) {
        final loc = LiveLocation.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
        await _cacheService.cacheLiveLocation(busId, loc);
        return loc;
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Failed to load live location: ${response.statusCode}');
      }
    } catch (e) {
      return await _cacheService.getCachedLiveLocation(busId);
    }
  }

  Future<bool> updateLocation({
    required int busId,
    required double latitude,
    required double longitude,
    required double speed,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/location/update'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'busId': busId,
          'latitude': latitude,
          'longitude': longitude,
          'speed': speed,
        }),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
