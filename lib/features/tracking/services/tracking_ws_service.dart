import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:anderson_crm_flutter/config/settings.dart';
import 'location_service.dart';

/// WebSocket service for real-time location tracking communication.
///
/// Connects to wss://server/tracking?token=JWT&role=technician|manager
/// Handles auto-reconnection with exponential backoff.
class TrackingWsService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  
  bool _isConnected = false;
  bool _shouldReconnect = true;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;

  /// Stream of incoming messages from the server
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  bool get isConnected => _isConnected;

  /// Connect to the tracking WebSocket server
  /// [token] - JWT auth token
  /// [role] - 'technician' or 'manager'
  Future<void> connect({
    required String token,
    required String role,
  }) async {
    if (_isConnected) return;
    _shouldReconnect = true;

    try {
      // Build WebSocket URL from the existing nodeUrl config
      // nodeUrl is like "https://hcdev.andrsn.click"
      // We need "wss://hcdev.andrsn.click/tracking?token=...&role=..."
      final baseUrl = Settings.nodeUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://');
      
      final wsUrl = '$baseUrl/tracking?token=$token&role=$role';
      
      debugPrint('[TrackingWS] Connecting as $role to $baseUrl/tracking...');

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      // Wait for the connection to be established
      await _channel!.ready;

      _isConnected = true;
      _reconnectAttempts = 0;
      debugPrint('[TrackingWS] Connected successfully');

      // Listen for incoming messages
      _subscription = _channel!.stream.listen(
        (dynamic data) {
          try {
            final message = jsonDecode(data.toString()) as Map<String, dynamic>;
            _messageController.add(message);

            if (kDebugMode && message['type'] != 'ack') {
              debugPrint('[TrackingWS] Received: ${message['type']}');
            }
          } catch (e) {
            debugPrint('[TrackingWS] Parse error: $e');
          }
        },
        onError: (error) {
          debugPrint('[TrackingWS] Stream error: $error');
          _handleDisconnect();
        },
        onDone: () {
          debugPrint('[TrackingWS] Connection closed');
          _handleDisconnect();
        },
      );
    } catch (e) {
      debugPrint('[TrackingWS] Connection failed: $e');
      _isConnected = false;
      _scheduleReconnect();
    }
  }

  /// Send a location ping to the server
  void sendLocation(LocationData location, {int? battery, String? currentWorkOrder}) {
    if (!_isConnected || _channel == null) return;

    final message = {
      'type': 'location',
      ...location.toJson(),
      if (battery != null) 'battery': battery,
      if (currentWorkOrder != null) 'current_work_order': currentWorkOrder,
    };

    try {
      _channel!.sink.add(jsonEncode(message));
    } catch (e) {
      debugPrint('[TrackingWS] Send error: $e');
    }
  }

  /// Send tracking stopped notification
  void sendTrackingStopped() {
    if (!_isConnected || _channel == null) return;
    try {
      _channel!.sink.add(jsonEncode({'type': 'tracking_stopped'}));
    } catch (e) {
      debugPrint('[TrackingWS] Send tracking_stopped error: $e');
    }
  }

  /// Handle disconnection — attempt reconnect
  void _handleDisconnect() {
    _isConnected = false;
    _subscription?.cancel();
    _subscription = null;

    if (_shouldReconnect) {
      _scheduleReconnect();
    }
  }

  /// Schedule reconnection with exponential backoff
  void _scheduleReconnect() {
    if (!_shouldReconnect) return;

    _reconnectTimer?.cancel();
    _reconnectAttempts++;

    // Exponential backoff: 1s, 2s, 4s, 8s, 16s, max 30s
    final delay = Duration(
      seconds: (_reconnectAttempts < 5)
          ? (1 << _reconnectAttempts)
          : 30,
    );

    debugPrint('[TrackingWS] Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts)...');

    _reconnectTimer = Timer(delay, () {
      // The caller needs to reconnect with token+role — 
      // we can't store them. The provider handles this.
      _messageController.add({'type': '_reconnect_needed'});
    });
  }

  /// Disconnect from the server
  Future<void> disconnect() async {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _subscription?.cancel();
    
    try {
      await _channel?.sink.close();
    } catch (_) {}
    
    _channel = null;
    _isConnected = false;
    debugPrint('[TrackingWS] Disconnected');
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
}
