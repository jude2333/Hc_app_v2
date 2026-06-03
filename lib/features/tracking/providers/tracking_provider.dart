import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:anderson_crm_flutter/config/settings.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import '../services/location_service.dart';
import '../services/tracking_ws_service.dart';
import '../services/location_cache_service.dart';

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

class TrackingNotifier extends StateNotifier<TrackingState> {
  final LocationService _locationService;
  final TrackingWsService _wsService;
  final Ref _ref;

  StreamSubscription? _locationSub;
  StreamSubscription? _wsSub;
  String? _jwtToken;
  String? _currentWorkOrderDocId;

  final _inMemoryCache = <Map<String, dynamic>>[];
  Timer? _flushTimer;
  int _persistedCacheSize = 0;

  TrackingNotifier(this._ref)
      : _locationService = LocationService(),
        _wsService = TrackingWsService(),
        super(const TrackingState());

  Future<void> initialize() async {
    final storage = _ref.read(storageServiceProvider);

    final empId = storage.getFromSession('logged_in_emp_id');
    final roleName = storage.getFromSession('role_name');
    _jwtToken = storage.getFromSession('pg_admin');

    if (empId.isEmpty || _jwtToken == null || _jwtToken!.isEmpty) {
      debugPrint('[Tracking] No auth info — skipping tracking init');
      return;
    }

    if (roleName.toUpperCase() != 'TECHNICIAN') {
      debugPrint(
          '[Tracking] User is $roleName — not starting technician tracking');
      return;
    }

    debugPrint('[Tracking] Initializing tracking for technician $empId');

    _persistedCacheSize = await LocationCacheService.getCacheSize();
    state = state.copyWith(cachedPings: _persistedCacheSize);

    _wsSub = _wsService.messageStream.listen(_handleWsMessage);

    _startFlushTimer();

    await _connectWebSocket();

    await startTracking();
  }

  void _startFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(
        const Duration(seconds: 60), (_) => _flushInMemoryCache());
  }

  void _stopFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = null;
  }

  Future<void> _flushInMemoryCache() async {
    if (_inMemoryCache.isEmpty) return;

    final pingsToCache = List<Map<String, dynamic>>.from(_inMemoryCache);
    _inMemoryCache.clear();

    await LocationCacheService.cachePings(pingsToCache);

    _persistedCacheSize = await LocationCacheService.getCacheSize();
    state = state.copyWith(cachedPings: _persistedCacheSize);
  }

  Future<void> _connectWebSocket() async {
    if (_jwtToken == null || _jwtToken!.isEmpty) return;

    try {
      await _wsService.connect(token: _jwtToken!, role: 'technician');
      state = state.copyWith(isConnected: true);

      await _flushInMemoryCache();

      await _syncCachedPings();
    } catch (e) {
      debugPrint('[Tracking] WebSocket connect error: $e');
      state = state.copyWith(isConnected: false);
    }
  }

  Future<void> startTracking() async {
    if (state.isTracking) return;

    await _locationService.startTracking(
      intervalMs: 10000,
      distanceFilter: 5,
    );

    _locationSub = _locationService.positionStream.listen(_onLocationUpdate);
    state = state.copyWith(isTracking: true);
    debugPrint('[Tracking] GPS tracking started');
  }

  Future<void> stopTracking() async {
    await _locationService.stopTracking();
    await _locationSub?.cancel();
    _locationSub = null;

    _wsService.sendTrackingStopped();
    state = state.copyWith(isTracking: false);
    debugPrint('[Tracking] GPS tracking stopped');
  }

  Future<void> toggleTracking() async {
    if (state.isTracking) {
      await stopTracking();
    } else {
      await startTracking();
    }
  }

  void setCurrentWorkOrder(String? docId) {
    _currentWorkOrderDocId = docId;
  }

  void _onLocationUpdate(LocationData location) {
    state = state.copyWith(lastLocation: location);

    if (_wsService.isConnected) {
      _wsService.sendLocation(
        location,
        battery: location.batteryLevel,
        currentWorkOrder: _currentWorkOrderDocId,
      );
    } else {
      _inMemoryCache.add({
        ...location.toJson(),
        'current_work_order': _currentWorkOrderDocId,
      });

      state = state.copyWith(
          cachedPings: _persistedCacheSize + _inMemoryCache.length);

      if (_inMemoryCache.length >= 5) {
        _flushInMemoryCache();
      }
    }
  }

  void _handleWsMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;

    switch (type) {
      case 'connected':
        debugPrint('[Tracking] Server acknowledged connection');
        state = state.copyWith(isConnected: true, error: null);
        break;
      case 'ack':
        break;
      case '_reconnect_needed':
        debugPrint('[Tracking] Reconnecting WebSocket...');
        _connectWebSocket();
        break;
      case '_reconnect_exhausted':
        debugPrint('[Tracking] Reconnect exhausted — connection lost');
        state = state.copyWith(
          isConnected: false,
          error: 'Connection lost — please re-login',
        );
        break;
      default:
        break;
    }
  }

  Future<void> _syncCachedPings() async {
    final pings = await LocationCacheService.peekCache();
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

      await LocationCacheService.clearCache();
      _persistedCacheSize = 0;
      state = state.copyWith(cachedPings: 0);
      debugPrint('[Tracking] Cached pings synced successfully');
    } catch (e) {
      debugPrint('[Tracking] Bulk sync failed (cache preserved): $e');
    }
  }

  Future<void> shutdown() async {
    _stopFlushTimer();
    await stopTracking();
    await _wsService.disconnect();
    await _wsSub?.cancel();
    await _locationService.dispose();

    await _flushInMemoryCache();

    _wsService.dispose();
  }
}

final trackingProvider =
    StateNotifierProvider<TrackingNotifier, TrackingState>((ref) {
  return TrackingNotifier(ref);
});
