import 'package:anderson_crm_flutter/services/storage_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';
import '../database/notifications.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import 'package:anderson_crm_flutter/providers/notification_provider.dart';
import 'package:anderson_crm_flutter/providers/db_handler_provider.dart';
import 'package:anderson_crm_flutter/features/core/util.dart';

class NotificationDBService {
  final Ref ref;

  NotificationDBService(this.ref);

  NotificationDB get _db => ref.read(notificationDbProvider);
  StorageService get _storage => ref.read(storageServiceProvider);

  void handleChanges() {}

  void updateStore() {}

  Future<List<Map<String, dynamic>>> getRemoteNotificationsList(
      String status) async {
    return await _db.listRemoteData(status);
  }

  Future<List<Map<String, dynamic>>> listRemoteData(String status) async {
    return await getRemoteNotificationsList(status);
  }

  Future<void> markAsSeen(String docId) async {
    await _db.markAsSeen(docId);
  }

  Future<String> updateNotification(Map<String, dynamic> doc) async {
    return await _db.doUpdate(doc);
  }

  Future<String> updateNotification2(Map<String, dynamic> doc) async {
    return await _db.doUpdate(doc);
  }

  Future<String> doUpdate(Map<String, dynamic> doc) async {
    return await updateNotification2(doc);
  }

  Future<Map<String, dynamic>?> getNotificationById2(String id) async {
    return await _db.getWithIdRemote(id);
  }

  Future<Map<String, dynamic>?> getWithIdRemote(String id) async {
    return await getNotificationById2(id);
  }

  Future<String> createNotification({
    required int toId,
    required String fromName,
    required String messageHeader,
    required String messageBody,
    String status = 'New',
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final notification = {
        '_id': 'notifications:${DateTime.now().millisecondsSinceEpoch}',
        'to_id': toId,
        'from_name': fromName,
        'msg_header': messageHeader,
        'msg_body': messageBody,
        'status': status,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        ...?additionalData,
      };

      return await updateNotification(notification);
    } catch (e) {
      debugPrint("Error creating notification: $e");
      return "ERROR: $e";
    }
  }

  Future<bool> deleteNotification(String notificationId) async {
    try {
      Box? localDb = await ref.read(dbHandlerProvider).getDb("notifications");
      if (localDb != null && localDb.containsKey(notificationId)) {
        await localDb.delete(notificationId);
        debugPrint("Notification deleted: $notificationId");
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error deleting notification: $e");
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getNotificationsByDateRange(
    DateTime startDate,
    DateTime endDate, [
    String? statusFilter,
  ]) async {
    try {
      String start = DateFormat('yyyy-MM-dd').format(startDate);
      String end = DateFormat('yyyy-MM-dd').format(endDate);

      int criteria = _getUserCriteria();
      Box? localDb = await ref.read(dbHandlerProvider).getDb("notifications");

      if (localDb == null) {
        debugPrint("Database is null for notifications");
        return [];
      }

      List<Map<String, dynamic>> filteredItems = [];
      Map<dynamic, dynamic> allDocs = localDb.toMap();

      for (var entry in allDocs.entries) {
        String key = entry.key.toString();

        if (_isWithinDateRange(key, start, end)) {
          Map<String, dynamic> doc = Map<String, dynamic>.from(entry.value);

          if (_isValidNotificationForUser(doc, criteria)) {
            if (statusFilter == null || doc['status'] == statusFilter) {
              String updated = Util.formatDate(doc['updated_at'] ?? '');
              doc['updated'] = updated;
              filteredItems.add(doc);
            }
          }
        }
      }

      filteredItems.sort((a, b) {
        DateTime dateA =
            DateTime.tryParse(a['updated_at'] ?? '') ?? DateTime.now();
        DateTime dateB =
            DateTime.tryParse(b['updated_at'] ?? '') ?? DateTime.now();
        return dateB.compareTo(dateA);
      });

      return filteredItems;
    } catch (e) {
      debugPrint("Error getting notifications by date range: $e");
      return [];
    }
  }

  int _getUserCriteria() {
    String empIdStr = _storage.getFromSession("logged_in_emp_id");
    int criteria = int.tryParse(empIdStr) ?? 0;

    String departmentName = _storage.getFromSession("department_name");
    String roleName = _storage.getFromSession("role_name");

    if (departmentName == "HOME COLLECTION" && roleName == "TECHNICIAN") {
      criteria = int.tryParse(_storage.getFromSession("logged_in_emp_id")) ?? 0;
    }

    return criteria;
  }

  bool _isWithinDateRange(String key, String startDate, String endDate) {
    return key.startsWith("notifications:") &&
        key.compareTo("notifications:$startDate") >= 0 &&
        key.compareTo("notifications:$endDate\ufff0") <= 0;
  }

  bool _isValidNotificationForUser(dynamic doc, int criteria) {
    return doc != null && doc['from_name'] != null && doc['to_id'] == criteria;
  }
}

final notificationDBServiceProvider = Provider<NotificationDBService>((ref) {
  return NotificationDBService(ref);
});
