import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:powersync/powersync.dart';
import 'package:anderson_crm_flutter/database/couch_db.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/config/settings.dart';

List<WorkOrder> _parseWorkOrdersIsolate(List<Map<String, dynamic>> rows) {
  return rows.map((row) => WorkOrder.fromRow(row)).toList();
}

class BillingWorkOrderRepository {
  final PowerSyncDatabase _db;
  final CouchDBClient _couchClient;

  BillingWorkOrderRepository(this._db, this._couchClient);

  DateTime _getBaseDate() {
    if (Settings.development) {
      return DateTime(2022, 12, 14);
    }
    return DateTime.now();
  }

  Future<List<WorkOrder>> getUnbilledOrders() async {
    final baseDate = _getBaseDate();
    final sevenDaysAgo = baseDate.subtract(const Duration(days: 7));
    final dateStr = DateFormat('yyyy-MM-dd').format(sevenDaysAgo);

    debugPrint(
        '[BillingRepo] Fetching unbilled from $dateStr (base: $baseDate)');

    final results = await _db.getAll('''
      SELECT * FROM hc_patient_visit_detail
      WHERE status = 'Finished'
        AND server_status = 'Received'
        AND visible = 1
        AND visit_date >= ?
      ORDER BY last_updated_at ASC
    ''', [dateStr]);

    debugPrint(
        '[BillingRepo] Parsing ${results.length} unbilled orders in isolate');

    if (results.length > 50) {
      return compute(_parseWorkOrdersIsolate, results);
    }

    return results.map((row) => WorkOrder.fromRow(row)).toList();
  }

  Future<List<WorkOrder>> getBilledOrders() async {
    final baseDate = _getBaseDate();
    final sevenDaysAgo = baseDate.subtract(const Duration(days: 7));
    final dateStr = DateFormat('yyyy-MM-dd').format(sevenDaysAgo);

    debugPrint('[BillingRepo] Fetching billed from $dateStr (base: $baseDate)');

    final results = await _db.getAll('''
      SELECT * FROM hc_patient_visit_detail
      WHERE status = 'Finished'
        AND server_status = 'Billed'
        AND visible = 1
        AND visit_date >= ?
      ORDER BY last_updated_at DESC
    ''', [dateStr]);

    debugPrint(
        '[BillingRepo] Parsing ${results.length} billed orders in isolate');

    if (results.length > 50) {
      return compute(_parseWorkOrdersIsolate, results);
    }

    return results.map((row) => WorkOrder.fromRow(row)).toList();
  }

  Future<Map<String, dynamic>?> fetchBillingDoc({
    required String visitDate,
    required String billNumber,
  }) async {
    try {
      final parsed = DateFormat('dd-MM-yyyy').parse(visitDate);
      final formattedDate = DateFormat('yyyy-MM-dd').format(parsed);
      final docId = 'billing:$formattedDate:${billNumber.trim()}';

      debugPrint('[BillingRepo] Fetching billing doc: $docId');

      final dio = await _couchClient.getDB('andrsn_billing');
      final response = await dio.get('/$docId');

      if (response.statusCode == 200 && response.data != null) {
        final doc = response.data as Map<String, dynamic>;
        return {
          'status_in_number': doc['status_in_number'] ?? '',
          'report_status': doc['report_status'] ?? '',
          'report_path': doc['report_path'] ?? '',
          'bill_details': doc['bill_details'],
        };
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        debugPrint('[BillingRepo] Billing doc not found');
        return null;
      }
      debugPrint('[BillingRepo] Error fetching billing doc: $e');
      rethrow;
    } catch (e) {
      debugPrint('[BillingRepo] Error fetching billing doc: $e');
      return null;
    }
  }

  Future<void> billOrder({
    required WorkOrder workOrder,
    required String billNumber,
    required String labNumber,
  }) async {
    final billingDoc = await fetchBillingDoc(
      visitDate: workOrder.formattedShortDate,
      billNumber: billNumber,
    );

    final now = DateTime.now().toIso8601String();
    final Map<String, dynamic> updateData = {
      'server_status': 'Billed',
      'bill_number': billNumber.toUpperCase(),
      'lab_number': labNumber,
      'last_updated_at': now,
    };

    if (billingDoc != null) {
      updateData['status_in_number'] = billingDoc['status_in_number'];
      updateData['report_status'] = billingDoc['report_status'];
      updateData['report_path'] = billingDoc['report_path'];

      final billDetails = billingDoc['bill_details'];
      if (billDetails != null) {
        final billedBy = billDetails['BillUser'] ?? 'Unknown';
        final billedTime = billDetails['VisitDate'];
        String timelineEntry;
        if (billedTime != null) {
          final parsed = DateTime.tryParse(billedTime.toString());
          if (parsed != null) {
            timelineEntry =
                '${DateFormat('MMMM dd, h:mm a').format(parsed)} - $billedBy - Work Order Billed';
          } else {
            timelineEntry = '$billedTime - $billedBy - Work Order Billed';
          }
        } else {
          timelineEntry =
              '${DateFormat('MMMM dd, h:mm a').format(DateTime.now())} - $billedBy - Work Order Billed';
        }

        final currentTimeline = List<dynamic>.from(workOrder.timeLine);
        currentTimeline.add(timelineEntry);

        final updatedDoc = Map<String, dynamic>.from(workOrder.parsedDocMap);
        updatedDoc['time_line'] = currentTimeline;
        updatedDoc['status_in_number'] = billingDoc['status_in_number'];
        updatedDoc['report_status'] = billingDoc['report_status'];
        updatedDoc['report_path'] = billingDoc['report_path'];
        updatedDoc['bill_number'] = billNumber.toUpperCase();
        updatedDoc['lab_number'] = labNumber;
        updatedDoc['server_status'] = 'Billed';
        updateData['doc'] = updatedDoc;
      }
    }

    await _db.execute('''
      UPDATE hc_patient_visit_detail
      SET server_status = ?,
          bill_number = ?,
          lab_number = ?,
          last_updated_at = ?
      WHERE id = ?
    ''', [
      'Billed',
      billNumber.toUpperCase(),
      labNumber,
      now,
      workOrder.id,
    ]);

    debugPrint('[BillingRepo] Work order billed: ${workOrder.id}');
  }

  Future<void> updateBillingDocLink({
    required String visitDate,
    required String billNumber,
    required String workOrderDocId,
    required String tenantDbName,
  }) async {
    try {
      final parsed = DateFormat('dd-MM-yyyy').parse(visitDate);
      final formattedDate = DateFormat('yyyy-MM-dd').format(parsed);
      final docId = 'billing:$formattedDate:${billNumber.trim()}';

      final dio = await _couchClient.getDB('andrsn_billing');

      final getResponse = await dio.get('/$docId');
      if (getResponse.statusCode != 200) return;

      final doc = Map<String, dynamic>.from(getResponse.data);
      doc['doc_id'] = workOrderDocId;
      doc['tenant_db_name'] = tenantDbName;

      await dio.put('/$docId', data: doc);
      debugPrint('[BillingRepo] Billing doc updated with work order link');
    } catch (e) {
      debugPrint('[BillingRepo] Error updating billing doc: $e');
    }
  }
}
