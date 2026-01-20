// FILE: lib/services/notification_center.dart

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:anderson_crm_flutter/config/settings.dart';
import 'package:anderson_crm_flutter/services/storage_service.dart';
import 'package:anderson_crm_flutter/features/core/util.dart';

class NotificationCenter {
  final StorageService _storage;

  Dio? _client;
  String _resolvedDbName = "";

  NotificationCenter(this._storage);

  Future<void> _setup() async {
    // Resolve notifications database name
    _resolvedDbName = _resolveDbName("notifications");

    // Use Bearer token auth (same as Vue DBHandler.create() line 176)
    // Token comes from pg_admin session (same as Vue DBHandler.refreshToken() line 303)
    String token = _storage.getFromSession("pg_admin") ?? "";

    debugPrint(
        '🔑 Token for CouchDB: ${token.isNotEmpty ? "${token.substring(0, 20)}..." : "EMPTY!"}');

    final options = BaseOptions(
      baseUrl: '${Settings.remoteCouchUrl}/$_resolvedDbName',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      validateStatus: (status) => status != null && status < 500,
    );

    _client = Dio(options);

    debugPrint('📡 NotificationCenter setup complete for: $_resolvedDbName');
  }

  String _resolveDbName(String shortName) {
    if (shortName == "notifications") {
      return "chennai11_hc_notifications";
    }
    // Fallback for other databases
    return shortName;
  }

  Future<String> sendNotification(Map<String, dynamic> notification) async {
    // Always recreate client to ensure fresh auth
    await _setup();

    try {
      if (!notification.containsKey('_id')) {
        return 'Error: Notification must have an _id field';
      }

      String docId = notification['_id'];
      final fullUrl = '${Settings.remoteCouchUrl}/$_resolvedDbName/$docId';
      debugPrint('📤 Sending notification to: $fullUrl');

      // just ensure _id is set - no need to remove anything
      notification['_id'] = docId;

      Response response = await _client!.put(
        '/$docId',
        data: notification,
      );

      debugPrint('📥 Response status: ${response.statusCode}');
      debugPrint('📥 Response data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ Notification sent successfully: $docId');
        return 'OK';
      } else if (response.statusCode == 409) {
        debugPrint('⚠️ Notification conflict (409), resolving...');
        return await _resolveConflictAndRetry(docId, notification);
      } else {
        debugPrint('❌ Failed to send notification: ${response.statusCode}');
        debugPrint('❌ Response body: ${response.data}');
        return 'Error: ${response.statusMessage}';
      }
    } catch (error, stackTrace) {
      if (error is DioException) {
        debugPrint('❌ DioException: ${error.message}');
        debugPrint('❌ Request URL: ${error.requestOptions.uri}');
        debugPrint('❌ Response status: ${error.response?.statusCode}');
        debugPrint('❌ Response body: ${error.response?.data}');

        if (error.response?.statusCode == 409) {
          return await _resolveConflictAndRetry(
              notification['_id'], notification);
        }
      }

      debugPrint('❌ Error sending notification: $error');
      return 'Error: $error';
    }
  }

  /// Helper: Send work order completion notification
  Future<String> sendWorkOrderCompletedNotification({
    required String appointmentDate,
    required String appointmentTime,
    required String patientName,
    required String age,
    required String gender,
    required String address,
    required String mobile,
    required String pincode,
    required String freeText,
    required String managerId,
    required String managerName,
  }) async {
    String msgHeader =
        'Completed Collection $appointmentDate $appointmentTime.';
    String msgBody =
        'Completed home collection for $patientName ($age/$gender) '
        'address:$address mobile:$mobile pincode:$pincode $freeText';

    Map<String, dynamic> notification = {
      '_id': 'notifications:${Util.getDateForId()}:${Util.uuidv4()}',
      'from_id': _storage.getFromSession('logged_in_emp_id'),
      'from_name': _storage.getFromSession('logged_in_emp_name'),
      'to_id': managerId,
      'to_name': managerName,
      'msg_header': msgHeader,
      'msg_body': msgBody,
      'msg_attachment': {},
      'status': 'New',
      'msg_time': _getTodayWithTime(),
      'updated_at': _getTimeStamp(),
    };

    return await sendNotification(notification);
  }

  /// Helper: Send custom notification
  // Future<String> sendCustomNotification({
  //   required String toId,
  //   required String toName,
  //   required String msgHeader,
  //   required String msgBody,
  //   Map<String, dynamic>? msgAttachment,
  // }) async {
  //   Map<String, dynamic> notification = {
  //     '_id': 'notifications:${Util.getDateForId()}:${Util.uuidv4()}',
  //     'from_id': _storage.getFromSession('logged_in_emp_id'),
  //     'from_name': _storage.getFromSession('logged_in_emp_name'),
  //     'to_id': toId,
  //     'to_name': toName,
  //     'msg_header': msgHeader,
  //     'msg_body': msgBody,
  //     'msg_attachment': msgAttachment ?? {},
  //     'status': 'New',
  //     'msg_time': _getTodayWithTime(),
  //     'updated_at': _getTimeStamp(),
  //   };

  //   return await sendNotification(notification);
  // }

  Future<String> _resolveConflictAndRetry(
      String docId, Map<String, dynamic> localDoc) async {
    try {
      debugPrint('🔄 Fetching remote notification: $docId');

      Response getResponse = await _client!.get('/$docId');

      if (getResponse.statusCode == 200) {
        Map<String, dynamic> remoteDoc =
            Map<String, dynamic>.from(getResponse.data);
        String remoteRev = remoteDoc['_rev'];

        localDoc['_rev'] = remoteRev;

        Response retryResponse = await _client!.put('/$docId', data: localDoc);

        if (retryResponse.statusCode == 200 ||
            retryResponse.statusCode == 201) {
          debugPrint('✅ Notification updated after conflict');
          return 'OK';
        } else {
          return 'Error: Conflict resolution failed';
        }
      } else if (getResponse.statusCode == 404) {
        localDoc.remove('_rev');

        Response createResponse = await _client!.put('/$docId', data: localDoc);

        if (createResponse.statusCode == 200 ||
            createResponse.statusCode == 201) {
          debugPrint('✅ Notification created successfully');
          return 'OK';
        } else {
          return 'Error: Failed to create notification';
        }
      } else {
        return 'Error: Could not resolve conflict';
      }
    } catch (error) {
      debugPrint('❌ Error in conflict resolution: $error');
      return 'Error: $error';
    }
  }

  // No longer needed - using Basic auth which doesn't require token refresh
  Future<void> refreshToken() async {
    // Basic auth credentials are static, no refresh needed
    debugPrint(
        '🔄 NotificationCenter uses Basic auth - no token refresh needed');
  }

  String _getTodayWithTime() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }

  String _getTimeStamp() {
    return DateTime.now().toIso8601String();
  }
}
