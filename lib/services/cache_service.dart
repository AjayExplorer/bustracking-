import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bustracking/models/bus.dart';
import 'package:bustracking/models/stop.dart';
import 'package:bustracking/models/live_location.dart';

class CacheService {
  static const String _busesKey = 'cached_buses';
  static const String _stopsKeyPrefix = 'cached_stops_';
  static const String _locationKeyPrefix = 'cached_location_';

  Future<void> cacheBuses(List<Bus> buses) async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(buses.map((b) => b.toJson()).toList());
    await prefs.setString(_busesKey, data);
  }

  Future<List<Bus>?> getCachedBuses() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_busesKey);
    if (data == null) return null;
    final decoded = jsonDecode(data) as List;
    return decoded.map((item) => Bus.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<void> cacheStops(int busId, List<Stop> stops) async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(stops.map((s) => s.toJson()).toList());
    await prefs.setString('$_stopsKeyPrefix$busId', data);
  }

  Future<List<Stop>?> getCachedStops(int busId) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('$_stopsKeyPrefix$busId');
    if (data == null) return null;
    final decoded = jsonDecode(data) as List;
    return decoded.map((item) => Stop.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<void> cacheLiveLocation(int busId, LiveLocation location) async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(location.toJson());
    await prefs.setString('$_locationKeyPrefix$busId', data);
  }

  Future<LiveLocation?> getCachedLiveLocation(int busId) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('$_locationKeyPrefix$busId');
    if (data == null) return null;
    return LiveLocation.fromJson(jsonDecode(data) as Map<String, dynamic>);
  }
}
