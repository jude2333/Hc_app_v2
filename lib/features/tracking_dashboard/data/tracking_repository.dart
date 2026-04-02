import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:anderson_crm_flutter/config/settings.dart';
import 'tracking_models.dart';

/// Repository for tracking REST API calls.
/// All endpoints require JWT Bearer auth.
class TrackingRepository {
  final Dio _dio;

  TrackingRepository({required String token})
      : _dio = Dio(BaseOptions(
          baseUrl: '${Settings.nodeUrl}/tracking',
          headers: {'Authorization': 'Bearer $token'},
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
        ));

  /// Get all technicians' current status for the tenant
  Future<List<TechnicianStatus>> getStatus({int? tenantId}) async {
    try {
      final params = <String, dynamic>{};
      if (tenantId != null) params['tenant_id'] = tenantId;

      final response = await _dio.get('/status', queryParameters: params);
      final techs = (response.data['technicians'] as List)
          .map((t) => TechnicianStatus.fromJson(t))
          .toList();
      return techs;
    } catch (e) {
      debugPrint('[TrackingRepo] getStatus error: $e');
      return [];
    }
  }

  /// Get route history for a technician on a specific date
  Future<List<RoutePoint>> getRoute(int techId, String date) async {
    try {
      final response = await _dio.get('/route', queryParameters: {
        'tech_id': techId,
        'date': date,
      });
      final route = (response.data['route'] as List)
          .map((r) => RoutePoint.fromJson(r))
          .toList();
      return route;
    } catch (e) {
      debugPrint('[TrackingRepo] getRoute error: $e');
      return [];
    }
  }

  /// Get activity timeline for a technician on a specific date
  Future<List<TimelineSegment>> getTimeline(int techId, String date) async {
    try {
      final response = await _dio.get('/timeline', queryParameters: {
        'tech_id': techId,
        'date': date,
      });
      final timeline = (response.data['timeline'] as List)
          .map((t) => TimelineSegment.fromJson(t))
          .toList();
      return timeline;
    } catch (e) {
      debugPrint('[TrackingRepo] getTimeline error: $e');
      return [];
    }
  }

  /// Get alerts (paginated)
  Future<({List<TrackingAlert> alerts, int unreadCount})> getAlerts({
    int? tenantId,
    int limit = 50,
    int offset = 0,
    bool unreadOnly = false,
  }) async {
    try {
      final response = await _dio.get('/alerts', queryParameters: {
        if (tenantId != null) 'tenant_id': tenantId,
        'limit': limit,
        'offset': offset,
        'unread_only': unreadOnly.toString(),
      });
      final alerts = (response.data['alerts'] as List)
          .map((a) => TrackingAlert.fromJson(a))
          .toList();
      final unreadCount = response.data['unread_count'] as int? ?? 0;
      return (alerts: alerts, unreadCount: unreadCount);
    } catch (e) {
      debugPrint('[TrackingRepo] getAlerts error: $e');
      return (alerts: <TrackingAlert>[], unreadCount: 0);
    }
  }

  /// Mark alert as read
  Future<void> markAlertRead(int alertId) async {
    try {
      await _dio.put('/alerts/$alertId/read');
    } catch (e) {
      debugPrint('[TrackingRepo] markAlertRead error: $e');
    }
  }

  /// Mark all alerts as read
  Future<void> markAllAlertsRead() async {
    try {
      await _dio.put('/alerts/read-all');
    } catch (e) {
      debugPrint('[TrackingRepo] markAllAlertsRead error: $e');
    }
  }

  /// Get fences for tenant
  Future<List<Map<String, dynamic>>> getFences({int? tenantId}) async {
    try {
      final params = <String, dynamic>{};
      if (tenantId != null) params['tenant_id'] = tenantId;

      final response = await _dio.get('/fences', queryParameters: params);
      return List<Map<String, dynamic>>.from(response.data['fences'] ?? []);
    } catch (e) {
      debugPrint('[TrackingRepo] getFences error: $e');
      return [];
    }
  }

  /// Get daily analytics
  Future<List<Map<String, dynamic>>> getDailyAnalytics({
    int? tenantId,
    String? date,
  }) async {
    try {
      final response = await _dio.get('/analytics/daily', queryParameters: {
        if (tenantId != null) 'tenant_id': tenantId,
        if (date != null) 'date': date,
      });
      return List<Map<String, dynamic>>.from(response.data['analytics'] ?? []);
    } catch (e) {
      debugPrint('[TrackingRepo] getDailyAnalytics error: $e');
      return [];
    }
  }

  /// Get WebSocket connection health
  Future<Map<String, dynamic>> getHealth() async {
    try {
      final response = await _dio.get('/health');
      return response.data;
    } catch (e) {
      return {'status': 'ERROR', 'error': e.toString()};
    }
  }
}
