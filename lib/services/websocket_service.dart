import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:bustracking/models/live_location.dart';

enum WsStatus { disconnected, connecting, connected }

class WebSocketService {
  final _locationStreamController = StreamController<LiveLocation>.broadcast();
  final _statusStreamController = StreamController<WsStatus>.broadcast();
  
  WebSocketChannel? _channel;
  int? _currentBusId;
  bool _shouldReconnect = false;
  int _reconnectDelaySeconds = 2;
  WsStatus _status = WsStatus.disconnected;

  WebSocketService();

  String get wsBaseUrl {
    if (kIsWeb) return 'ws://localhost:8787';
    try {
      if (Platform.isAndroid) return 'ws://10.0.2.2:8787';
    } catch (_) {}
    return 'ws://127.0.0.1:8787';
  }

  Stream<LiveLocation> get locationStream => _locationStreamController.stream;
  Stream<WsStatus> get statusStream => _statusStreamController.stream;
  WsStatus get status => _status;

  void _updateStatus(WsStatus newStatus) {
    _status = newStatus;
    _statusStreamController.add(newStatus);
  }

  void connect(int busId) {
    if (_currentBusId == busId && _status == WsStatus.connected) return;
    
    disconnect();
    _currentBusId = busId;
    _shouldReconnect = true;
    _reconnectDelaySeconds = 2; // reset delay
    _establishConnection();
  }

  void disconnect() {
    _shouldReconnect = false;
    _channel?.sink.close();
    _channel = null;
    _updateStatus(WsStatus.disconnected);
  }

  void _establishConnection() {
    if (_currentBusId == null || !_shouldReconnect) return;

    _updateStatus(WsStatus.connecting);
    final url = '$wsBaseUrl/ws/location/$_currentBusId';
    
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      
      _channel!.stream.listen(
        (message) {
          // reset backoff on success
          _reconnectDelaySeconds = 2;
          _updateStatus(WsStatus.connected);
          
          try {
            final data = jsonDecode(message as String);
            final loc = LiveLocation.fromJson(data as Map<String, dynamic>);
            _locationStreamController.add(loc);
          } catch (e) {
            debugPrint("Error parsing WebSocket message: $e");
          }
        },
        onError: (err) {
          debugPrint("WebSocket error: $err");
          _handleDisconnect();
        },
        onDone: () {
          debugPrint("WebSocket closed");
          _handleDisconnect();
        },
      );
    } catch (e) {
      debugPrint("WebSocket connection exception: $e");
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    _channel = null;
    _updateStatus(WsStatus.disconnected);
    
    if (_shouldReconnect) {
      debugPrint("Attempting WebSocket reconnect in $_reconnectDelaySeconds seconds...");
      Timer(Duration(seconds: _reconnectDelaySeconds), () {
        // Exponential backoff capped at 30 seconds
        _reconnectDelaySeconds = (_reconnectDelaySeconds * 2).clamp(2, 30);
        _establishConnection();
      });
    }
  }

  void dispose() {
    disconnect();
    _locationStreamController.close();
    _statusStreamController.close();
  }
}
