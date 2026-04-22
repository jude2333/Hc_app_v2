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
  bool _isTracking = false;

  // Lazily created StreamController — recreated if previously closed.
  // This is critical because LocationService is a singleton: dispose() closes
  // the controller, but the singleton lives forever, and callers may restart
  // tracking later.
  StreamController<LocationData>? _positionController;

  StreamController<LocationData> get _controller {
    if (_positionController == null || _positionController!.isClosed) {
      _positionController = StreamController<LocationData>.broadcast();
    }
    return _positionController!;
  }

  /// Stream of location updates
  Stream<LocationData> get positionStream => _controller.stream;
  bool get isTracking => _isTracking;

  /// Request location permissions
  /// Returns true if all required permissions are granted.
  Future<bool> requestPermissions() async {
    // On web, the browser handles permissions via Geolocation API prompt
    if (kIsWeb) {
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          debugPrint('[Location] Location services are disabled');
          return false;
        }

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            debugPrint('[Location] Web location permission denied');
            return false;
          }
        }

        if (permission == LocationPermission.deniedForever) {
          debugPrint('[Location] Web location permission permanently denied');
          return false;
        }

        debugPrint('[Location] Web location permission granted');
        return true;
      } catch (e) {
        debugPrint('[Location] Web permission error: $e');
        return false;
      }
    }

    // Native Android/iOS flow
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
    var bgStatus = await Permission.locationAlways.request();
    if (!bgStatus.isGranted) {
      debugPrint('[Location] Background location permission denied (non-blocking)');
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

    // Use platform-appropriate settings
    late LocationSettings locationSettings;

    if (kIsWeb) {
      // Web: use basic settings (no AndroidSettings/foreground service on web)
      locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter.toInt(),
        timeLimit: null,
      );
      debugPrint('[Location] Using Web location settings');
    } else {
      // Android/iOS: use AndroidSettings with foreground service
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter.toInt(),
        intervalDuration: Duration(milliseconds: intervalMs),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Anderson CRM',
          notificationText: 'Location tracking active',
          enableWakeLock: true,
        ),
      );
      debugPrint('[Location] Using Android location settings');
    }

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

        // Guard: geolocator_web can fire one last callback after cancel()
        // due to the browser's watchPosition race. If controller was closed
        // between cancel and this callback, silently drop the event.
        if (!_controller.isClosed) {
          _controller.add(locationData);
        }

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
  Future<void> stopTracking() async {
    await _positionSubscription?.cancel();
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

  Future<void> dispose() async {
    await stopTracking();
    _positionController?.close();
    _positionController = null;
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
