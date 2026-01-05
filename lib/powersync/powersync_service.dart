import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:powersync/powersync.dart' hide Table, Column, Index;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import '../../models/schema.dart';
import '../../models/work_order.dart';
import 'backend_connector.dart';
import '../../services/storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/util.dart';

class PowerSyncService {
  static PowerSyncService? _instance;
  late PowerSyncDatabase db;
  late BackendConnector _connector;
  bool _initialized = false;
  Completer<void>? _initCompleter;

  PowerSyncService._();

  static PowerSyncService get instance {
    _instance ??= PowerSyncService._();
    return _instance!;
  }

  bool get isInitialized => _initialized;

  Future<String> _getDatabasePath() async {
    if (kIsWeb) {
      return 'powersync_hc_visit_detail.db';
    } else {
      final dir = await getApplicationDocumentsDirectory();
      return join(dir.path, 'powersync_hc_visit_detail.db');
    }
  }

  Future<void> initialize(StorageService storage) async {
    if (_initialized) return;

    if (_initCompleter != null) {
      return _initCompleter!.future;
    }

    _initCompleter = Completer<void>();

    try {
      final path = await _getDatabasePath();
      db = PowerSyncDatabase(schema: schema, path: path);
      await db.initialize();

      _connector = BackendConnector(storage: storage);
      await db.connect(connector: _connector);

      _initialized = true;
      _initCompleter!.complete();
    } catch (e) {
      _initCompleter!.completeError(e);
      _initCompleter = null;
      rethrow;
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      throw StateError('PowerSync not initialized. Call initialize() first.');
    }
  }

  // Returns List<Map> so Isolate can parse it
  Stream<List<Map<String, dynamic>>> watchWorkOrdersByDate(
      DateTime selectedDate) {
    final dateStr = selectedDate.toIso8601String().split('T')[0];

    return db.watch(
      'SELECT * FROM hc_patient_visit_detail WHERE visible = 1 AND visit_date = ? ORDER BY visit_time ASC',
      parameters: [dateStr],
    ).map((rows) {
      // Convert SqliteRow to Map<String, dynamic>
      return rows.map((r) => Map<String, dynamic>.from(r)).toList();
    });
  }

  //  Returns List<Map> so Isolate can parse it
  Stream<List<Map<String, dynamic>>> watchTechnicianWorkOrders(String techId) {
    return db.watch(
      '''
        SELECT * FROM hc_patient_visit_detail 
        WHERE assigned_id = ? AND visible = 1
        ORDER BY visit_time ASC
        ''',
      parameters: [techId],
    ).map((rows) {
      return rows.map((r) => Map<String, dynamic>.from(r)).toList();
    });
  }

  Future<void> createWorkOrder(WorkOrder order) async {
    await _ensureInitialized();
    final data = order.toMap();

    await db.execute('''
    INSERT INTO hc_patient_visit_detail (
      id, tenant_id, hcpm_id, doc_id, patient_name, visit_date, visit_time,
      doctor_name, pro_id, manager_id, manager_name, assigned_id, assigned_to,
      b2b_client_id, b2b_client_name, status, server_status, 
      bill_amount, received_amount, discount_amount, doc,
      bill_number, lab_number, visible, created_by, created_at, 
      last_updated_by, last_updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  ''', [
      data['id'],
      data['tenant_id'],
      data['hcpm_id'],
      data['doc_id'],
      data['patient_name'],
      data['visit_date'],
      data['visit_time'],
      data['doctor_name'],
      data['pro_id'],
      data['manager_id'],
      data['manager_name'],
      data['assigned_id'],
      data['assigned_to'],
      data['b2b_client_id'],
      data['b2b_client_name'],
      data['status'],
      data['server_status'],
      data['bill_amount'],
      data['received_amount'],
      data['discount_amount'],
      data['doc'],
      data['bill_number'],
      data['lab_number'],
      data['visible'],
      data['created_by'],
      data['created_at'],
      data['last_updated_by'],
      data['last_updated_at'],
    ]);
  }

  Future<bool> updateWorkOrder(
    WorkOrder workOrder, {
    Map<String, dynamic>? customDoc,
  }) async {
    await _ensureInitialized();

    try {
      final data = workOrder.toMap();
      final now = DateTime.now().toIso8601String();
      final docToUse = customDoc != null ? jsonEncode(customDoc) : data['doc'];

      await db.execute(
        '''
      UPDATE hc_patient_visit_detail 
      SET 
        patient_name = ?, visit_date = ?, visit_time = ?, doctor_name = ?, 
        manager_id = ?, manager_name = ?, assigned_id = ?, assigned_to = ?, 
        b2b_client_id = ?, b2b_client_name = ?, 
        status = ?, server_status = ?, bill_amount = ?, received_amount = ?, 
        discount_amount = ?, doc = ?, last_updated_by = ?, last_updated_at = ?
      WHERE id = ?
      ''',
        [
          data['patient_name'],
          data['visit_date'],
          data['visit_time'],
          data['doctor_name'],
          data['manager_id'],
          data['manager_name'],
          data['assigned_id'],
          data['assigned_to'],
          data['b2b_client_id'],
          data['b2b_client_name'],
          data['status'],
          data['server_status'],
          data['bill_amount'],
          data['received_amount'],
          data['discount_amount'],
          docToUse,
          data['last_updated_by'],
          now,
          data['id'],
        ],
      );
      return true;
    } catch (e) {
      debugPrint('❌ UPDATE failed: $e');
      return false;
    }
  }

  Future<void> softDeleteWorkOrder(int id, String user) async {
    await _ensureInitialized();
    final now = DateTime.now().toIso8601String();
    await db.execute(
      'UPDATE hc_patient_visit_detail SET visible = 0, last_updated_by = ?, last_updated_at = ? WHERE id = ?',
      [user, now, id],
    );
  }

  Future<void> deleteWorkOrder(int id) async {
    await _ensureInitialized();
    await db.execute('DELETE FROM hc_patient_visit_detail WHERE id = ?', [id]);
  }

  Stream<SyncStatus> watchStatus() {
    return db.statusStream;
  }

  bool get isConnected => db.currentStatus.connected;

  Future<Map<String, dynamic>?> getWorkOrderById(String docId) async {
    final row = await db.get(
      'SELECT * FROM hc_patient_visit_detail WHERE doc_id = ? LIMIT 1',
      [docId],
    );
    return row != null ? Map<String, dynamic>.from(row) : null;
  }

  Future<List<Map<String, dynamic>>> getTechnicianDailyOrders(
      String techId, String dateStr) async {
    final results = await db.getAll(
      '''
      SELECT * FROM hc_patient_visit_detail 
      WHERE assigned_id = ? AND visit_date = ? AND visible = 1
      ''',
      [techId, dateStr],
    );

    return results.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<void> submitRemittance(
      List<Map<String, dynamic>> rawOrders, String amount, String user) async {
    await _ensureInitialized();

    final timeStamp = Util.gettime();
    final logEntry = '$timeStamp - $user - Amount Remitted';
    final now = DateTime.now().toIso8601String();

    await db.writeTransaction((tx) async {
      for (var row in rawOrders) {
        final docStr = row['doc'] as String;
        final Map<String, dynamic> doc = jsonDecode(docStr);

        doc['amount_deposit'] = amount;
        doc['amount_deposited_status'] = false;

        List<dynamic> timeline = List.from(doc['time_line'] ?? []);
        timeline.add(logEntry);
        doc['time_line'] = timeline;

        doc['updated_at'] = now;

        await tx.execute(
          '''
          UPDATE hc_patient_visit_detail 
          SET doc = ?, last_updated_by = ?, last_updated_at = ? 
          WHERE id = ?
          ''',
          [jsonEncode(doc), user, now, row['id']],
        );
      }
    });
  }

  // cancel work order

  Stream<List<Map<String, dynamic>>> watchCancelledWorkOrdersByDate(
      DateTime date) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    return db.watch(
      '''
      SELECT * FROM hc_patient_visit_detail 
      WHERE visit_date = ? 
      AND (status = 'cancelled' OR server_status = 'cancelled') 
      AND visible = 1
      ORDER BY visit_time DESC
      ''',
      parameters: [dateStr],
    ).map((rows) => rows.map((r) => Map<String, dynamic>.from(r)).toList());
  }

  Future<void> waitForSync() async {
    await Future.delayed(const Duration(seconds: 3));
  }

// This is used to calculate aggregates for ALL technicians.
  Future<List<Map<String, dynamic>>> getAllWorkOrdersForDate(
      String dateStr) async {
    final results = await db.getAll(
      '''
      SELECT * FROM hc_patient_visit_detail 
      WHERE visit_date = ? AND visible = 1
      ''',
      [dateStr],
    );
    // Return as modifiable list
    return results.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  // 2. Manager Actions: Toggle Remittance Acceptance

  Future<void> toggleRemittanceAcceptance(
      String id, bool status, String user) async {
    await _ensureInitialized();
    final timeStamp = Util.gettime();
    final actionLog = status ? "Remittance Accepted." : "Remittance Cancelled.";
    final logEntry = '$timeStamp - $user - $actionLog';
    final now = DateTime.now().toIso8601String();

    await db.writeTransaction((tx) async {
      // 1. Get current doc to modify JSON fields
      final result = await tx
          .get('SELECT doc FROM hc_patient_visit_detail WHERE id = ?', [id]);
      if (result == null) return;

      final docMap = jsonDecode(result['doc'] as String);

      // 2. Update JSON fields
      docMap['accept_remittance'] = status;

      // 3. Update Timeline
      List<dynamic> timeline = List.from(docMap['time_line'] ?? []);
      timeline.add(logEntry);
      docMap['time_line'] = timeline;

      docMap['updated_at'] = now;

      // 4. Update Database
      await tx.execute(
        '''
        UPDATE hc_patient_visit_detail 
        SET doc = ?, last_updated_by = ?, last_updated_at = ? 
        WHERE id = ?
        ''',
        [jsonEncode(docMap), user, now, id],
      );
    });
  }

  Future<List<Map<String, dynamic>>> getAllWorkOrdersForDateRange(
      String startDate, String endDate) async {
    final results = await db.getAll(
      '''
      SELECT * FROM hc_patient_visit_detail 
      WHERE visit_date >= ? AND visit_date <= ? AND visible = 1
      ''',
      [startDate, endDate],
    );
    return results.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<void> dispose() async {
    await db.disconnect();
    await db.close();
    _initialized = false;
  }
}

final powerSyncServiceProvider = Provider<PowerSyncService>((ref) {
  return PowerSyncService.instance;
});
