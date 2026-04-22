// Data models for the tracking dashboard

class TechnicianStatus {
  final int technicianId;
  final int tenantId;
  final String technicianName;
  final bool isOnline;
  final bool isTracking;
  final double? lastLatitude;
  final double? lastLongitude;
  final double? lastAccuracy;
  final int? lastBattery;
  final double? lastSpeed;
  final String? lastActivity;
  final DateTime? lastSeenAt;
  final double todayDistance;
  final int todayPings;
  final String? currentWorkOrder;
  final DateTime? updatedAt;

  TechnicianStatus({
    required this.technicianId,
    required this.tenantId,
    required this.technicianName,
    this.isOnline = false,
    this.isTracking = false,
    this.lastLatitude,
    this.lastLongitude,
    this.lastAccuracy,
    this.lastBattery,
    this.lastSpeed,
    this.lastActivity,
    this.lastSeenAt,
    this.todayDistance = 0,
    this.todayPings = 0,
    this.currentWorkOrder,
    this.updatedAt,
  });

  factory TechnicianStatus.fromJson(Map<String, dynamic> json) {
    return TechnicianStatus(
      technicianId: json['technician_id'] is int
          ? json['technician_id']
          : int.tryParse(json['technician_id'].toString()) ?? 0,
      tenantId: json['tenant_id'] is int
          ? json['tenant_id']
          : int.tryParse(json['tenant_id'].toString()) ?? 0,
      technicianName: json['technician_name'] ?? 'Unknown',
      isOnline: json['is_online'] == true,
      isTracking: json['is_tracking'] == true,
      lastLatitude: _toDouble(json['last_latitude']),
      lastLongitude: _toDouble(json['last_longitude']),
      lastAccuracy: _toDouble(json['last_accuracy']),
      lastBattery: json['last_battery'] is int ? json['last_battery'] : null,
      lastSpeed: _toDouble(json['last_speed']),
      lastActivity: json['last_activity'],
      lastSeenAt: json['last_seen_at'] != null
          ? DateTime.tryParse(json['last_seen_at'].toString())
          : null,
      todayDistance: _toDouble(json['today_distance']) ?? 0,
      todayPings: json['today_pings'] is int ? json['today_pings'] : 0,
      currentWorkOrder: json['current_work_order'],
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  /// Status label for display
  String get statusLabel {
    if (!isOnline) return 'Offline';
    if (lastActivity == 'stationary' || lastSpeed == null || lastSpeed! < 0.5) {
      return 'Idle';
    }
    return 'Moving';
  }

  /// Speed in km/h
  double get speedKmh => (lastSpeed ?? 0) * 3.6;

  /// Has valid coordinates
  bool get hasLocation => lastLatitude != null && lastLongitude != null;

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class RoutePoint {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? speed;
  final double? heading;
  final double? altitude;
  final int? batteryLevel;
  final bool isMoving;
  final String? activityType;
  final DateTime recordedAt;

  RoutePoint({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.speed,
    this.heading,
    this.altitude,
    this.batteryLevel,
    this.isMoving = true,
    this.activityType,
    required this.recordedAt,
  });

  factory RoutePoint.fromJson(Map<String, dynamic> json) {
    return RoutePoint(
      latitude: TechnicianStatus._toDouble(json['latitude']) ?? 0,
      longitude: TechnicianStatus._toDouble(json['longitude']) ?? 0,
      accuracy: TechnicianStatus._toDouble(json['accuracy']),
      speed: TechnicianStatus._toDouble(json['speed']),
      heading: TechnicianStatus._toDouble(json['heading']),
      altitude: TechnicianStatus._toDouble(json['altitude']),
      batteryLevel: json['battery_level'] is int ? json['battery_level'] : null,
      isMoving: json['is_moving'] == true,
      activityType: json['activity_type'],
      recordedAt: DateTime.parse(json['recorded_at'].toString()),
    );
  }

  double get speedKmh => (speed ?? 0) * 3.6;
}

class TimelineSegment {
  final String activity;
  final DateTime startAt;
  final DateTime endAt;
  final double startLat;
  final double startLng;
  final int? battery;
  final int pings;
  final int durationMin;

  TimelineSegment({
    required this.activity,
    required this.startAt,
    required this.endAt,
    required this.startLat,
    required this.startLng,
    this.battery,
    this.pings = 0,
    this.durationMin = 0,
  });

  factory TimelineSegment.fromJson(Map<String, dynamic> json) {
    return TimelineSegment(
      activity: json['activity'] ?? 'unknown',
      startAt: DateTime.parse(json['start_at'].toString()),
      endAt: DateTime.parse(json['end_at'].toString()),
      startLat: TechnicianStatus._toDouble(json['start_lat']) ?? 0,
      startLng: TechnicianStatus._toDouble(json['start_lng']) ?? 0,
      battery: json['battery'] is int ? json['battery'] : null,
      pings: json['pings'] is int ? json['pings'] : 0,
      durationMin: json['duration_min'] is int ? json['duration_min'] : 0,
    );
  }
}

class TrackingAlert {
  final int id;
  final int tenantId;
  final int technicianId;
  final String? technicianName;
  final String alertType;
  final String? message;
  final String severity;
  final double? latitude;
  final double? longitude;
  final bool isRead;
  final DateTime createdAt;

  TrackingAlert({
    required this.id,
    required this.tenantId,
    required this.technicianId,
    this.technicianName,
    required this.alertType,
    this.message,
    this.severity = 'warning',
    this.latitude,
    this.longitude,
    this.isRead = false,
    required this.createdAt,
  });

  factory TrackingAlert.fromJson(Map<String, dynamic> json) {
    return TrackingAlert(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      tenantId: json['tenant_id'] is int ? json['tenant_id'] : 0,
      technicianId: json['technician_id'] is int ? json['technician_id'] : 0,
      technicianName: json['technician_name'],
      alertType: json['alert_type'] ?? '',
      message: json['message'],
      severity: json['severity'] ?? 'warning',
      latitude: TechnicianStatus._toDouble(json['latitude']),
      longitude: TechnicianStatus._toDouble(json['longitude']),
      isRead: json['is_read'] == true,
      createdAt: DateTime.parse(json['created_at'].toString()),
    );
  }

  /// Icon for the alert type
  String get icon {
    switch (alertType) {
      case 'offline_timeout': return '📡';
      case 'battery_low': return '🔋';
      case 'speed_exceeded': return '🏎️';
      case 'fence_exit': return '🚧';
      case 'idle_too_long': return '💤';
      case 'gps_mock_detected': return '⚠️';
      case 'tracking_disabled': return '📍';
      default: return '🔔';
    }
  }

  bool get isCritical => severity == 'critical';
}
