import 'package:anderson_crm_flutter/services/storage_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';

import '../database/work_orderDb.dart';

import '../providers/app_state.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import 'package:anderson_crm_flutter/providers/db_handler_provider.dart';

class WorkOrderDBService {
  final Ref ref;

  WorkOrderDBService(this.ref);

  WorkOrderDB get _db => ref.read(workOrderDbProvider);
  StorageService get _storage => ref.read(storageServiceProvider);

  // static final Function _debouncedUpdateStore = Util.debounce(() {}, 500);

  void handleChanges() {
    // WorkOrderDB.handleChanges(ref); // Removed
  }

  void updateStore() {
    // WorkOrderDB.updateStore(ref); // Removed
  }

  Future<List<Map<String, dynamic>>> getWorkOrdersList(String thisDate) async {
    return await _db.list(thisDate);
  }

  Future<List<Map<String, dynamic>>> list(String thisDate) async {
    return await getWorkOrdersList(thisDate);
  }

  Future<List<Map<String, dynamic>>> getRemoteWorkOrdersList(
      String thisDate) async {
    return await _db.listRemoteData(thisDate);
  }

  Future<List<Map<String, dynamic>>> listRemoteData(String thisDate) async {
    return await getRemoteWorkOrdersList(thisDate);
  }

  Future<String> updateWorkOrder(Map<String, dynamic> doc) async {
    return await _db.doUpdate(doc);
  }

  Future<String> doUpdate(Map<String, dynamic> doc) async {
    return await updateWorkOrder(doc);
  }

  Future<String> doUpdate2(Map<String, dynamic> doc) async {
    return await _db.doUpdate2(doc);
  }

  Future<Map<String, dynamic>?> getWorkOrderByIdRemote(String id) async {
    return await _db.getWithIdRemote(id);
  }

  Future<Map<String, dynamic>?> getWithIdRemote(String id) async {
    return await getWorkOrderByIdRemote(id);
  }

  Future<List<Map<String, dynamic>>> getAssignedWorkOrders(String id) async {
    return await _db.assignedList(id);
  }

  Future<List<Map<String, dynamic>>> assignedList(String id) async {
    return await getAssignedWorkOrders(id);
  }

  Future<List<Map<String, dynamic>>> getBilledWorkOrders(
    String status,
    String serverStatus,
  ) async {
    String today = ref.read(appNotifierProvider).today;
    return await _db.billedList(status, serverStatus, today);
  }

  Future<List<Map<String, dynamic>>> billedList(
    String status,
    String serverStatus,
  ) async {
    return await getBilledWorkOrders(status, serverStatus);
  }

  Future<List<Map<String, dynamic>>> assignedListRemote(String empId) async {
    return await _db.assignedListRemote(empId);
  }

  Future<String> updateAmountDeposit(List<Map<String, dynamic>> docs) async {
    return await _db.updateAmountDeposit(docs);
  }

  Future<int> getPendingWorkOrderCount(String assignedId) async {
    try {
      final assignedOrders = await getAssignedWorkOrders(assignedId);

      return assignedOrders
          .where((order) =>
              order['name'] != "No Appointments Found." &&
              order['status'] != 'Finished' &&
              order['status'] != 'cancelled')
          .length;
    } catch (e) {
      debugPrint("Error getting pending work order count: $e");
      return 0;
    }
  }

  Future<int> getFinishedWorkOrderCount(String assignedId,
      [String? date]) async {
    try {
      final targetDate =
          date ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
      final assignedOrders = await getAssignedWorkOrders(assignedId);

      return assignedOrders
          .where((order) =>
              order['name'] != "No Appointments Found." &&
              order['status'] == 'Finished' &&
              order['appointment_date'] == targetDate)
          .length;
    } catch (e) {
      debugPrint("Error getting finished work order count: $e");
      return 0;
    }
  }

  Future<String> createWorkOrder({
    required String name,
    required String appointmentDate,
    required String appointmentTime,
    required int assignedId,
    String status = 'Assigned',
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final workOrder = {
        '_id':
            'work_order:$appointmentDate:${DateTime.now().millisecondsSinceEpoch}',
        'name': name,
        'appointment_date': appointmentDate,
        'appointment_time': appointmentTime,
        'assigned_id': assignedId,
        'status': status,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        ...?additionalData,
      };

      return await updateWorkOrder(workOrder);
    } catch (e) {
      debugPrint("Error creating work order: $e");
      return "ERROR: $e";
    }
  }

  Future<bool> deleteWorkOrder(String workOrderId) async {
    try {
      Box? localDb = await ref.read(dbHandlerProvider).getDb("work_orders");
      if (localDb != null && localDb.containsKey(workOrderId)) {
        await localDb.delete(workOrderId);
        debugPrint("Work order deleted: $workOrderId");
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error deleting work order: $e");
      return false;
    }
  }

  Future<Map<String, int>> getWorkOrderStats([int? assignedId]) async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final todayOrders = await getWorkOrdersList(today);

      List<Map<String, dynamic>> validOrders = todayOrders;

      if (assignedId != null) {
        validOrders = validOrders
            .where((order) => order['assigned_id'] == assignedId)
            .toList();
      }

      validOrders = validOrders
          .where((order) => order['name'] != "No Appointments Found.")
          .toList();

      final stats = <String, int>{
        'total': validOrders.length,
        'assigned': 0,
        'finished': 0,
        'cancelled': 0,
        'pending': 0,
      };

      for (final order in validOrders) {
        final status = order['status']?.toString().toLowerCase() ?? 'unknown';
        switch (status) {
          case 'assigned':
            stats['assigned'] = (stats['assigned'] ?? 0) + 1;
            stats['pending'] = (stats['pending'] ?? 0) + 1;
            break;
          case 'finished':
            stats['finished'] = (stats['finished'] ?? 0) + 1;
            break;
          case 'cancelled':
            stats['cancelled'] = (stats['cancelled'] ?? 0) + 1;
            break;
          default:
            stats['pending'] = (stats['pending'] ?? 0) + 1;
            break;
        }
      }

      return stats;
    } catch (e) {
      debugPrint("Error getting work order stats: $e");
      return {
        'total': 0,
        'assigned': 0,
        'finished': 0,
        'cancelled': 0,
        'pending': 0
      };
    }
  }

  Future<List<Map<String, dynamic>>> getTechAggregateView(
    String id,
    String thisDate,
  ) async {
    return await _db.techAggregateView(id, thisDate);
  }

  Future<List<Map<String, dynamic>>> getAggregateView(
    String startDate,
    String endDate, [
    bool local = true,
  ]) async {
    return await _db.aggregateView(startDate, endDate, local);
  }

  Future<List<Map<String, dynamic>>> getCanceledWorkOrders(
      String thisDate) async {
    return await _db.canceledWorkOrder(thisDate);
  }

  Future<List<Map<String, dynamic>>> getTechEngagements(
    String startDate,
    String endDate,
    List<Map<String, dynamic>> technicians, [
    bool local = true,
  ]) async {
    return await _db.techEngagements(startDate, endDate, technicians, local);
  }

  Future<List<Map<String, dynamic>>> getTechSampleVerification(
    String thisDate,
    List<Map<String, dynamic>> technicians,
  ) async {
    return await _db.techSampleVerification(thisDate, technicians);
  }

  Future<List<Map<String, dynamic>>> getTodayWorkOrders() async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final empId = _storage.getFromSession("logged_in_emp_id");

      if (empId.isEmpty) return [];

      final assignedOrders = await getAssignedWorkOrders(empId);

      return assignedOrders
          .where((order) =>
              order['name'] != "No Appointments Found." &&
              order['appointment_date'] == today)
          .toList();
    } catch (e) {
      debugPrint("Error getting today's work orders: $e");
      return [];
    }
  }

  bool _isValidStatusTransition(String? currentStatus, String targetStatus) {
    const validTransitions = {
      'assigned': ['finished', 'cancelled'],
      'pending': ['assigned', 'finished', 'cancelled'],
      'finished': [],
      'cancelled': [],
    };

    if (currentStatus == null) return true;

    return validTransitions[currentStatus]?.contains(targetStatus) ?? false;
  }
}

final workOrderDBServiceProvider = Provider<WorkOrderDBService>((ref) {
  return WorkOrderDBService(ref);
});
