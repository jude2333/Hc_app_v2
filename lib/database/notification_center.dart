// FILE: lib/services/notification_center.dart

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:anderson_crm_flutter/config/settings.dart';
import 'package:anderson_crm_flutter/services/storage_service.dart';
import 'package:anderson_crm_flutter/util.dart';

class NotificationCenter {
  final StorageService _storage;

  Dio? _client;
  String _token = "";
  String _resolvedDbName = "";

  NotificationCenter(this._storage);

  Future<void> _setup() async {
    if (_token.isEmpty) {
      _token = _storage.getFromSession("pg_admin");
    }

    // Resolve notifications database name
    _resolvedDbName = _resolveDbName("notifications");

    final options = BaseOptions(
      baseUrl: '${Settings.remoteCouchUrl}/$_resolvedDbName',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    );

    final headers = <String, String>{
      "Content-Type": "application/json",
    };

    if (_token.isNotEmpty) {
      headers["Authorization"] = "Bearer $_token";
    }

    _client = Dio(options)
      ..options.headers = headers
      ..options.validateStatus = (status) => status != null && status < 500;

    debugPrint('📡 NotificationCenter setup complete for: $_resolvedDbName');
  }

  /// Resolve database name (notifications → chennai11_hc_notifications)
  String _resolveDbName(String shortName) {
    String? docDbs = _storage.getFromSession("doc_dbs");

    if (docDbs != null && docDbs.isNotEmpty) {
      List<String> dbNames = docDbs.split(",");

      for (String dbName in dbNames) {
        if (dbName.endsWith(shortName)) {
          debugPrint('✅ Resolved "$shortName" → "$dbName"');
          return dbName;
        }
      }
    }

    debugPrint('⚠️ Could not resolve "$shortName", using as-is');
    return shortName;
  }

  Future<String> sendNotification(Map<String, dynamic> notification) async {
    if (_client == null) {
      await _setup();
    }

    try {
      if (!notification.containsKey('_id')) {
        return 'Error: Notification must have an _id field';
      }

      String docId = notification['_id'];
      debugPrint('📤 Sending notification to $_resolvedDbName: $docId');

      // ✅ Just ensure _id is set - no need to remove anything
      notification['_id'] = docId;

      Response response = await _client!.put(
        '/$docId',
        data: notification,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ Notification sent successfully: $docId');
        return 'OK';
      } else if (response.statusCode == 409) {
        debugPrint('⚠️ Notification conflict (409), resolving...');
        return await _resolveConflictAndRetry(docId, notification);
      } else {
        debugPrint('❌ Failed to send notification: ${response.statusCode}');
        return 'Error: ${response.statusMessage}';
      }
    } catch (error, stackTrace) {
      if (error is DioException && error.response?.statusCode == 409) {
        return await _resolveConflictAndRetry(
            notification['_id'], notification);
      }

      debugPrint('❌ Error sending notification: $error');
      debugPrint('Stack trace: $stackTrace');
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

  Future<void> refreshToken() async {
    _token = _storage.getFromSession("pg_admin");

    if (_client != null && _token.isNotEmpty) {
      _client!.options.headers["Authorization"] = "Bearer $_token";
      debugPrint('🔄 Token refreshed in NotificationCenter');
    }
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
