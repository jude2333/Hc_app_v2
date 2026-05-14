import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:anderson_crm_flutter/config/settings.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import '../services/location_service.dart';
import '../services/tracking_ws_service.dart';
import '../services/location_cache_service.dart';

/// Tracking state
class TrackingState {
  final bool isTracking;
  final bool isConnected;
  final int cachedPings;
  final LocationData? lastLocation;
  final String? error;

  const TrackingState({
    this.isTracking = false,
    this.isConnected = false,
    this.cachedPings = 0,
    this.lastLocation,
    this.error,
  });

  TrackingState copyWith({
    bool? isTracking,
    bool? isConnected,
    int? cachedPings,
    LocationData? lastLocation,
    String? error,
  }) {
    return TrackingState(
      isTracking: isTracking ?? this.isTracking,
      isConnected: isConnected ?? this.isConnected,
      cachedPings: cachedPings ?? this.cachedPings,
      lastLocation: lastLocation ?? this.lastLocation,
      error: error,
    );
  }
}

/// Main tracking provider — orchestrates GPS + WebSocket + caching
class TrackingNotifier extends StateNotifier<TrackingState> {
  final LocationService _locationService;
  final TrackingWsService _wsService;
  final Ref _ref;

  StreamSubscription? _locationSub;
  StreamSubscription? _wsSub;
  String? _jwtToken;
  String? _currentWorkOrderDocId;

  TrackingNotifier(this._ref)
      : _locationService = LocationService(),
        _wsService = TrackingWsService(),
        super(const TrackingState());

  /// Initialize tracking — called after login
  /// Auto-starts tracking if the user is a technician
  Future<void> initialize() async {
    final storage = _ref.read(storageServiceProvider);

    // Get auth info from session — use the correct keys
    final empId = storage.getFromSession('logged_in_emp_id');
    final roleName = storage.getFromSession('role_name');
    _jwtToken = storage.getFromSession('pg_admin');

    if (empId.isEmpty || _jwtToken == null || _jwtToken!.isEmpty) {
      debugPrint('[Tracking] No auth info — skipping tracking init');
      return;
    }

    // Only auto-start for technicians
    if (roleName.toUpperCase() != 'TECHNICIAN') {
      debugPrint('[Tracking] User is $roleName — not starting technician tracking');
      return;
    }

    debugPrint('[Tracking] Initializing tracking for technician $empId');

    // Listen for WebSocket messages
    _wsSub = _wsService.messageStream.listen(_handleWsMessage);

    // Connect WebSocket
    await _connectWebSocket();

    // Start GPS tracking
    await startTracking();
  }

  /// Connect to the tracking WebSocket server
  Future<void> _connectWebSocket() async {
    if (_jwtToken == null || _jwtToken!.isEmpty) return;

    try {
      await _wsService.connect(token: _jwtToken!, role: 'technician');
      state = state.copyWith(isConnected: true);

      // Sync any cached pings
      await _syncCachedPings();
    } catch (e) {
      debugPrint('[Tracking] WebSocket connect error: $e');
      state = state.copyWith(isConnected: false);
    }
  }

  /// Start GPS position streaming
  Future<void> startTracking() async {
    if (state.isTracking) return;

    await _locationService.startTracking(
      intervalMs: 10000,   // 10 seconds — live tracking
      distanceFilter: 5,   // 5 meters
    );

    _locationSub = _locationService.positionStream.listen(_onLocationUpdate);
    state = state.copyWith(isTracking: true);
    debugPrint('[Tracking] GPS tracking started');
  }

  /// Stop GPS tracking
  Future<void> stopTracking() async {
    await _locationService.stopTracking();
    await _locationSub?.cancel();
    _locationSub = null;

    _wsService.sendTrackingStopped();
    state = state.copyWith(isTracking: false);
    debugPrint('[Tracking] GPS tracking stopped');
  }

  /// Toggle tracking on/off
  Future<void> toggleTracking() async {
    if (state.isTracking) {
      await stopTracking();
    } else {
      await startTracking();
    }
  }

  /// Set the current work order being serviced
  void setCurrentWorkOrder(String? docId) {
    _currentWorkOrderDocId = docId;
  }

  /// Handle GPS location update
  void _onLocationUpdate(LocationData location) {
    state = state.copyWith(lastLocation: location);

    if (_wsService.isConnected) {
      // Send via WebSocket (with battery)
      _wsService.sendLocation(
        location,
        battery: location.batteryLevel,
        currentWorkOrder: _currentWorkOrderDocId,
      );
    } else {
      // Cache for later
      LocationCacheService.cachePing({
        ...location.toJson(),
        'current_work_order': _currentWorkOrderDocId,
      });
      LocationCacheService.getCacheSize().then((size) {
        state = state.copyWith(cachedPings: size);
      });
    }
  }

  /// Handle WebSocket messages
  void _handleWsMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;

    switch (type) {
      case 'connected':
        debugPrint('[Tracking] Server acknowledged connection');
        state = state.copyWith(isConnected: true);
        break;
      case 'ack':
        // Location ping acknowledged — nothing to do
        break;
      case '_reconnect_needed':
        // Internal signal to reconnect
        debugPrint('[Tracking] Reconnecting WebSocket...');
        _connectWebSocket();
        break;
      default:
        break;
    }
  }

  /// Sync cached pings to server via REST bulk endpoint
  Future<void> _syncCachedPings() async {
    final pings = await LocationCacheService.drainCache();
    if (pings.isEmpty) return;

    debugPrint('[Tracking] Syncing ${pings.length} cached pings...');

    try {
      final dio = Dio();
      await dio.post(
        '${Settings.nodeUrl}/tracking/bulk',
        data: {'pings': pings},
        options: Options(
          headers: {'Authorization': 'Bearer $_jwtToken'},
        ),
      );
      state = state.copyWith(cachedPings: 0);
      debugPrint('[Tracking] Cached pings synced successfully');
    } catch (e) {
      debugPrint('[Tracking] Bulk sync failed: $e');
      // Re-cache the pings
      for (final ping in pings) {
        await LocationCacheService.cachePing(ping);
      }
    }
  }

  /// Full cleanup — called on logout
  Future<void> shutdown() async {
    await stopTracking();
    await _wsService.disconnect();
    await _wsSub?.cancel();
    await _locationService.dispose();
    _wsService.dispose();
  }
}

/// Riverpod provider
final trackingProvider =
    StateNotifierProvider<TrackingNotifier, TrackingState>((ref) {
  return TrackingNotifier(ref);
});
