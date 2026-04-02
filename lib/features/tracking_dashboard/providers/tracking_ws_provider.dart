import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/config/settings.dart';
import '../data/tracking_models.dart';

/// WebSocket provider for the manager dashboard.
/// Connects as role=manager and receives live technician updates.
class TrackingDashboardWsNotifier extends StateNotifier<DashboardWsState> {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  String? _token;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _shouldReconnect = true;

  TrackingDashboardWsNotifier() : super(const DashboardWsState());

  /// Stream of raw WS events for the dashboard to react to
  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;

  /// Connect to tracking WS as manager
  Future<void> connect(String token) async {
    _token = token;
    _shouldReconnect = true;

    try {
      final baseUrl = Settings.nodeUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://');

      final wsUrl = '$baseUrl/tracking?token=$token&role=manager';
      debugPrint('[DashboardWS] Connecting as manager...');

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      await _channel!.ready;

      state = state.copyWith(isConnected: true);
      _reconnectAttempts = 0;
      debugPrint('[DashboardWS] Connected');

      _subscription = _channel!.stream.listen(
        (dynamic data) {
          try {
            final message = jsonDecode(data.toString()) as Map<String, dynamic>;
            _handleMessage(message);
          } catch (e) {
            debugPrint('[DashboardWS] Parse error: $e');
          }
        },
        onError: (error) {
          debugPrint('[DashboardWS] Error: $error');
          _handleDisconnect();
        },
        onDone: () {
          debugPrint('[DashboardWS] Closed');
          _handleDisconnect();
        },
      );
    } catch (e) {
      debugPrint('[DashboardWS] Connect failed: $e');
      state = state.copyWith(isConnected: false);
      _scheduleReconnect();
    }
  }

  void _handleMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;

    switch (type) {
      case 'initial_status':
        // Full list of technician statuses on first connect
        final techs = (message['technicians'] as List?)
            ?.map((t) => TechnicianStatus.fromJson(t))
            .toList() ?? [];
        
        final techMap = <int, TechnicianStatus>{};
        for (final tech in techs) {
          techMap[tech.technicianId] = tech;
        }
        state = state.copyWith(technicians: techMap);
        debugPrint('[DashboardWS] Received initial status: ${techs.length} technicians');
        break;

      case 'tech_location':
        // Live location update from a technician
        final techId = message['technician_id'] as int;
        final existing = state.technicians[techId];
        
        final updated = TechnicianStatus(
          technicianId: techId,
          tenantId: existing?.tenantId ?? 0,
          technicianName: message['technician_name'] ?? existing?.technicianName ?? 'Unknown',
          isOnline: true,
          isTracking: true,
          lastLatitude: (message['lat'] as num?)?.toDouble(),
          lastLongitude: (message['lng'] as num?)?.toDouble(),
          lastAccuracy: (message['accuracy'] as num?)?.toDouble(),
          lastBattery: message['battery'] as int?,
          lastSpeed: (message['speed'] as num?)?.toDouble(),
          lastActivity: message['activity_type'],
          lastSeenAt: DateTime.now(),
          todayDistance: existing?.todayDistance ?? 0,
          todayPings: (existing?.todayPings ?? 0) + 1,
          currentWorkOrder: message['current_work_order'],
        );

        final newTechs = Map<int, TechnicianStatus>.from(state.technicians);
        newTechs[techId] = updated;
        state = state.copyWith(technicians: newTechs);
        break;

      case 'tech_status':
        // Online/offline status change
        final techId = message['technician_id'] as int;
        final status = message['status'] as String?;
        final existing = state.technicians[techId];

        if (existing != null) {
          final updated = TechnicianStatus(
            technicianId: techId,
            tenantId: existing.tenantId,
            technicianName: message['technician_name'] ?? existing.technicianName,
            isOnline: status == 'online',
            isTracking: status == 'online' ? existing.isTracking : false,
            lastLatitude: existing.lastLatitude,
            lastLongitude: existing.lastLongitude,
            lastBattery: existing.lastBattery,
            lastSpeed: existing.lastSpeed,
            lastActivity: existing.lastActivity,
            lastSeenAt: existing.lastSeenAt,
            todayDistance: existing.todayDistance,
            todayPings: existing.todayPings,
            currentWorkOrder: existing.currentWorkOrder,
          );
          final newTechs = Map<int, TechnicianStatus>.from(state.technicians);
          newTechs[techId] = updated;
          state = state.copyWith(technicians: newTechs);
        }
        break;

      case 'alert':
        // New alert
        final alertData = message['alert'] as Map<String, dynamic>?;
        if (alertData != null) {
          final alert = TrackingAlert.fromJson(alertData);
          final newAlerts = [alert, ...state.recentAlerts];
          if (newAlerts.length > 50) newAlerts.removeLast();
          state = state.copyWith(
            recentAlerts: newAlerts,
            unreadAlertCount: state.unreadAlertCount + 1,
          );
        }
        break;
    }

    // Forward all events for custom listeners
    _eventController.add(message);
  }

  void _handleDisconnect() {
    state = state.copyWith(isConnected: false);
    _subscription?.cancel();
    if (_shouldReconnect && _token != null) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    final delay = Duration(seconds: _reconnectAttempts < 5 ? (1 << _reconnectAttempts) : 30);
    debugPrint('[DashboardWS] Reconnecting in ${delay.inSeconds}s...');
    _reconnectTimer = Timer(delay, () {
      if (_token != null) connect(_token!);
    });
  }

  Future<void> disconnect() async {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    try { await _channel?.sink.close(); } catch (_) {}
    _channel = null;
    state = state.copyWith(isConnected: false);
  }

  @override
  void dispose() {
    disconnect();
    _eventController.close();
    super.dispose();
  }
}

/// Dashboard WebSocket state
class DashboardWsState {
  final bool isConnected;
  final Map<int, TechnicianStatus> technicians;
  final List<TrackingAlert> recentAlerts;
  final int unreadAlertCount;

  const DashboardWsState({
    this.isConnected = false,
    this.technicians = const {},
    this.recentAlerts = const [],
    this.unreadAlertCount = 0,
  });

  DashboardWsState copyWith({
    bool? isConnected,
    Map<int, TechnicianStatus>? technicians,
    List<TrackingAlert>? recentAlerts,
    int? unreadAlertCount,
  }) {
    return DashboardWsState(
      isConnected: isConnected ?? this.isConnected,
      technicians: technicians ?? this.technicians,
      recentAlerts: recentAlerts ?? this.recentAlerts,
      unreadAlertCount: unreadAlertCount ?? this.unreadAlertCount,
    );
  }

  /// Get technicians as a sorted list (online first, then by name)
  List<TechnicianStatus> get technicianList {
    final list = technicians.values.toList();
    list.sort((a, b) {
      if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
      return a.technicianName.compareTo(b.technicianName);
    });
    return list;
  }

  int get onlineCount => technicians.values.where((t) => t.isOnline).length;
  int get totalCount => technicians.length;
}

/// Riverpod provider
final dashboardWsProvider =
    StateNotifierProvider<TrackingDashboardWsNotifier, DashboardWsState>((ref) {
  return TrackingDashboardWsNotifier();
});
