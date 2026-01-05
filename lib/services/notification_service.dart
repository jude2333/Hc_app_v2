import 'package:anderson_crm_flutter/services/storage_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';
import '../database/notifications.dart';
import '../providers/app_state.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import 'package:anderson_crm_flutter/providers/notification_provider.dart';
import 'package:anderson_crm_flutter/providers/db_handler_provider.dart';
import 'package:anderson_crm_flutter/util.dart';

class NotificationDBService {
  final Ref ref;

  NotificationDBService(this.ref);

  NotificationDB get _db => ref.read(notificationDbProvider);
  StorageService get _storage => ref.read(storageServiceProvider);

  // static final Function _debouncedUpdateStore = Util.debounce(() {}, 500);

  void handleChanges() {
    // NotificationDB.handleChanges(ref); // No longer needed
  }

  void updateStore() {
    // NotificationDB.updateStore(ref); // No longer needed
  }

  Future<List<Map<String, dynamic>>> getNotificationsList(String status) async {
    String today = ref.read(appNotifierProvider).today;
    return await _db.list(status, today);
  }

  Future<List<Map<String, dynamic>>> list(String status) async {
    return await getNotificationsList(status);
  }

  Future<List<Map<String, dynamic>>> getRemoteNotificationsList(
      String status) async {
    String today = ref.read(appNotifierProvider).today;
    return await _db.listRemoteData(status, today);
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

  Future<String> doUpdate(Map<String, dynamic> doc) async {
    return await updateNotification(doc);
  }

  Future<String> updateNotification2(Map<String, dynamic> doc) async {
    return await _db.doUpdate2(doc);
  }

  Future<String> doUpdate2(Map<String, dynamic> doc) async {
    return await updateNotification2(doc);
  }

  Future<Map<String, dynamic>?> getNotificationById(String id) async {
    return await _db.getWithId(id);
  }

  Future<Map<String, dynamic>?> getWithId(String id) async {
    return await getNotificationById(id);
  }

  Future<Map<String, dynamic>?> getNotificationById2(String id) async {
    return await _db.getWithIdRemote(id);
  }

  Future<Map<String, dynamic>?> getWithIdRemote(String id) async {
    return await getNotificationById2(id);
  }

  Future<List<Map<String, dynamic>>> getAllNotifications() async {
    String today = ref.read(appNotifierProvider).today;
    return await _db.listAll(today);
  }

  Future<List<Map<String, dynamic>>> listAll() async {
    return await getAllNotifications();
  }

  Future<int> getNewNotificationCount() async {
    try {
      final newNotifications = await getNotificationsList("New");

      return newNotifications
          .where((notification) =>
              notification['from_name'] != "No Notifications Found.")
          .length;
    } catch (e) {
      debugPrint("Error getting new notification count: $e");
      return 0;
    }
  }

  Future<bool> markAsRead(String notificationId) async {
    try {
      final notification = await getNotificationById(notificationId);
      if (notification != null) {
        notification['status'] = 'Read';
        notification['updated_at'] = DateTime.now().toIso8601String();
        final result = await updateNotification(notification);
        return result == "OK";
      }
      return false;
    } catch (e) {
      debugPrint("Error marking notification as read: $e");
      return false;
    }
  }

  Future<bool> markAllAsRead() async {
    try {
      final newNotifications = await getNotificationsList("New");
      bool allSuccess = true;

      for (final notification in newNotifications) {
        if (notification['from_name'] != "No Notifications Found.") {
          notification['status'] = 'Read';
          notification['updated_at'] = DateTime.now().toIso8601String();
          final result = await updateNotification(notification);
          if (result != "OK") {
            allSuccess = false;
          }
        }
      }

      return allSuccess;
    } catch (e) {
      debugPrint("Error marking all notifications as read: $e");
      return false;
    }
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

  Future<Map<String, int>> getNotificationStats() async {
    try {
      final allNotifications = await getAllNotifications();
      final validNotifications = allNotifications
          .where((notification) =>
              notification['from_name'] != "No Notifications Found.")
          .toList();

      final stats = <String, int>{
        'total': validNotifications.length,
        'new': 0,
        'read': 0,
        'archived': 0,
      };

      for (final notification in validNotifications) {
        final status =
            notification['status']?.toString().toLowerCase() ?? 'unknown';
        switch (status) {
          case 'new':
            stats['new'] = (stats['new'] ?? 0) + 1;
            break;
          case 'read':
            stats['read'] = (stats['read'] ?? 0) + 1;
            break;
          case 'archived':
            stats['archived'] = (stats['archived'] ?? 0) + 1;
            break;
        }
      }

      return stats;
    } catch (e) {
      debugPrint("Error getting notification stats: $e");
      return {'total': 0, 'new': 0, 'read': 0, 'archived': 0};
    }
  }

  Future<int> archiveOldNotifications(int olderThanDays) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: olderThanDays));
      Box? localDb = await ref.read(dbHandlerProvider).getDb("notifications");

      if (localDb == null) return 0;

      int archivedCount = 0;
      Map<dynamic, dynamic> allDocs = localDb.toMap();

      for (var entry in allDocs.entries) {
        String key = entry.key.toString();
        if (key.startsWith("notifications:")) {
          Map<String, dynamic> doc = Map<String, dynamic>.from(entry.value);

          DateTime? updatedAt = DateTime.tryParse(doc['updated_at'] ?? '');
          if (updatedAt != null && updatedAt.isBefore(cutoffDate)) {
            if (doc['status'] != 'archived') {
              doc['status'] = 'archived';
              doc['updated_at'] = DateTime.now().toIso8601String();
              await localDb.put(key, doc);
              archivedCount++;
            }
          }
        }
      }

      return archivedCount;
    } catch (e) {
      debugPrint("Error archiving old notifications: $e");
      return 0;
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
