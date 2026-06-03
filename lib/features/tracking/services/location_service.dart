import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:battery_plus/battery_plus.dart';

class LocationService {
  static final LocationService _instance = LocationService._();
  factory LocationService() => _instance;
  LocationService._();

  StreamSubscription<Position>? _positionSubscription;
  bool _isTracking = false;
  final Battery _battery = Battery();

  StreamController<LocationData>? _positionController;

  StreamController<LocationData> get _controller {
    if (_positionController == null || _positionController!.isClosed) {
      _positionController = StreamController<LocationData>.broadcast();
    }
    return _positionController!;
  }

  Stream<LocationData> get positionStream => _controller.stream;
  bool get isTracking => _isTracking;

  Future<bool> requestPermissions() async {
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

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[Location] Location services are disabled');
      return false;
    }

    var status = await Permission.location.request();
    if (!status.isGranted) {
      debugPrint('[Location] Foreground location permission denied');
      return false;
    }

    var bgStatus = await Permission.locationAlways.request();
    if (!bgStatus.isGranted) {
      debugPrint(
          '[Location] Background location permission denied (non-blocking)');
    }

    debugPrint('[Location] Permissions granted');
    return true;
  }

  Future<void> startTracking({
    int intervalMs = 3000,
    double distanceFilter = 2.0,
  }) async {
    if (_isTracking) return;

    final hasPermission = await requestPermissions();
    if (!hasPermission) {
      debugPrint('[Location] Cannot start tracking — permissions not granted');
      return;
    }

    late LocationSettings locationSettings;

    if (kIsWeb) {
      locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter.toInt(),
        timeLimit: null,
      );
      debugPrint('[Location] Using Web location settings');
    } else {
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
      (Position position) async {
        int? battery;
        try {
          battery = await _battery.batteryLevel;
        } catch (_) {}

        final locationData = LocationData(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          speed: position.speed,
          heading: position.heading,
          altitude: position.altitude,
          isMock: position.isMocked,
          timestamp: position.timestamp,
          batteryLevel: battery,
        );

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
    debugPrint(
        '[Location] Tracking started (interval: ${intervalMs}ms, filter: ${distanceFilter}m)');
  }

  Future<void> stopTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _isTracking = false;
    debugPrint('[Location] Tracking stopped');
  }

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

  Future<int?> getBatteryLevel() async {
    try {
      return await _battery.batteryLevel;
    } catch (e) {
      debugPrint('[Location] Battery read error: $e');
      return null;
    }
  }

  Future<void> dispose() async {
    await stopTracking();
    _positionController?.close();
    _positionController = null;
    _isTracking = false;
  }
}

class LocationData {
  final double latitude;
  final double longitude;
  final double accuracy;
  final double speed;
  final double heading;
  final double altitude;
  final bool isMock;
  final DateTime? timestamp;
  final int? batteryLevel;

  LocationData({
    required this.latitude,
    required this.longitude,
    this.accuracy = 0,
    this.speed = 0,
    this.heading = 0,
    this.altitude = 0,
    this.isMock = false,
    this.timestamp,
    this.batteryLevel,
  });

  bool get isMoving => speed > 0.5;

  double get speedKmh => speed * 3.6;

  String get activityType {
    if (speed < 0.5) return 'stationary';
    if (speed < 2.0) return 'walking';
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
        'battery_level': batteryLevel,
        'recorded_at': (timestamp ?? DateTime.now()).toUtc().toIso8601String(),
      };
}
