import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Wraps the Geolocator plugin for GPS position streaming.
/// Handles permission requests and provides a position stream.
class LocationService {
  static final LocationService _instance = LocationService._();
  factory LocationService() => _instance;
  LocationService._();

  StreamSubscription<Position>? _positionSubscription;
  final _positionController = StreamController<LocationData>.broadcast();
  bool _isTracking = false;

  /// Stream of location updates
  Stream<LocationData> get positionStream => _positionController.stream;
  bool get isTracking => _isTracking;

  /// Request location permissions (Android)
  /// Returns true if all required permissions are granted.
  Future<bool> requestPermissions() async {
    // 1. Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[Location] Location services are disabled');
      return false;
    }

    // 2. Request foreground location permission
    var status = await Permission.location.request();
    if (!status.isGranted) {
      debugPrint('[Location] Foreground location permission denied');
      return false;
    }

    // 3. Request "always" (background) location permission
    // On Android 10+, this opens the special settings page
    var bgStatus = await Permission.locationAlways.request();
    if (!bgStatus.isGranted) {
      debugPrint('[Location] Background location permission denied (non-blocking)');
      // Don't return false — foreground tracking still works
      // Background will be limited but functional
    }

    debugPrint('[Location] Permissions granted');
    return true;
  }

  /// Start streaming GPS positions
  /// [intervalMs] - minimum time between updates (default 30s)
  /// [distanceFilter] - minimum distance change in meters (default 10m)
  Future<void> startTracking({
    int intervalMs = 30000,
    double distanceFilter = 10.0,
  }) async {
    if (_isTracking) return;

    final hasPermission = await requestPermissions();
    if (!hasPermission) {
      debugPrint('[Location] Cannot start tracking — permissions not granted');
      return;
    }

    final locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilter.toInt(),
      intervalDuration: Duration(milliseconds: intervalMs),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'Anderson CRM',
        notificationText: 'Location tracking active',
        enableWakeLock: true,
      ),
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        final locationData = LocationData(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          speed: position.speed,
          heading: position.heading,
          altitude: position.altitude,
          isMock: position.isMocked,
          timestamp: position.timestamp,
        );

        _positionController.add(locationData);

        if (kDebugMode) {
          debugPrint(
            '[Location] ${position.latitude.toStringAsFixed(6)}, '
            '${position.longitude.toStringAsFixed(6)} '
            '(acc: ${position.accuracy.toStringAsFixed(1)}m, '
            'spd: ${(position.speed * 3.6).toStringAsFixed(1)}km/h)',
          );
        }
      },
      onError: (error) {
        debugPrint('[Location] Position stream error: $error');
      },
    );

    _isTracking = true;
    debugPrint('[Location] Tracking started (interval: ${intervalMs}ms, filter: ${distanceFilter}m)');
  }

  /// Stop GPS streaming
  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _isTracking = false;
    debugPrint('[Location] Tracking stopped');
  }

  /// Get current position once (for initial location)
  Future<LocationData?> getCurrentPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        speed: position.speed,
        heading: position.heading,
        altitude: position.altitude,
        isMock: position.isMocked,
        timestamp: position.timestamp,
      );
    } catch (e) {
      debugPrint('[Location] getCurrentPosition error: $e');
      return null;
    }
  }

  /// Get battery level (0-100)
  Future<int?> getBatteryLevel() async {
    // Battery info isn't available via geolocator — use device_info_plus
    // For now, return null and let the caller provide it
    return null;
  }

  void dispose() {
    stopTracking();
    _positionController.close();
  }
}

/// Data class for a GPS location reading
class LocationData {
  final double latitude;
  final double longitude;
  final double accuracy;
  final double speed; // m/s
  final double heading; // degrees 0-360
  final double altitude;
  final bool isMock;
  final DateTime? timestamp;

  LocationData({
    required this.latitude,
    required this.longitude,
    this.accuracy = 0,
    this.speed = 0,
    this.heading = 0,
    this.altitude = 0,
    this.isMock = false,
    this.timestamp,
  });

  /// Whether the device is moving (speed > 0.5 m/s ≈ 1.8 km/h)
  bool get isMoving => speed > 0.5;

  /// Speed in km/h
  double get speedKmh => speed * 3.6;

  /// Activity type based on speed
  String get activityType {
    if (speed < 0.5) return 'stationary';
    if (speed < 2.0) return 'walking'; // < 7.2 km/h
    return 'driving';
  }

  Map<String, dynamic> toJson() => {
    'lat': latitude,
    'lng': longitude,
    'accuracy': accuracy,
    'speed': speed,
    'heading': heading,
    'altitude': altitude,
    'is_mock': isMock,
    'is_moving': isMoving,
    'activity_type': activityType,
    'recorded_at': (timestamp ?? DateTime.now()).toUtc().toIso8601String(),
  };
}
