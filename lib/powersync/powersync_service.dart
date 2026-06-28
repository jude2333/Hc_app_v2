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
import 'package:anderson_crm_flutter/features/core/util.dart';

class PowerSyncService {
  static PowerSyncService? _instance;
  late PowerSyncDatabase db;
  late BackendConnector _connector;
  bool _initialized = false;
  Completer<void>? _initCompleter;

  /// Set to false for production to suppress verbose sync logging.
  static const bool _debugSync = false;

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

  Future<void> initialize(
    StorageService storage, {
    Future<void> Function()? onRefreshToken,
  }) async {
    if (_initialized) return;

    if (_initCompleter != null) {
      return _initCompleter!.future;
    }

    _initCompleter = Completer<void>();

    try {
      final path = await _getDatabasePath();
      db = PowerSyncDatabase(schema: schema, path: path);
      await db.initialize();

      _connector = BackendConnector(
        storage: storage,
        onRefreshToken: onRefreshToken,
      );
      // await db.connect(connector: _connector);
      await db.connect(connector: _connector);

      // Monitor sync status and auto-reconnect on stalls
      _setupSyncRecovery();

      _initialized = true;
      _initCompleter!.complete();

      // Only run debug checks in development mode with debug flag
      if (_debugSync &&
          const bool.fromEnvironment('dart.vm.product') == false) {
        _debugCheckLocalDatabase();
      }
    } catch (e) {
      _initCompleter!.completeError(e);
      _initCompleter = null;
      rethrow;
    }
  }

  Future<void> _debugCheckLocalDatabase() async {
    try {
      // Check tables
      final tables = await db.getAll(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
      );
      debugPrint(
          ' [PowerSync DEBUG] Tables in local DB: ${tables.map((t) => t['name']).toList()}');

      // Check record count
      final count = await db.get(
        'SELECT COUNT(*) as cnt FROM hc_patient_visit_detail',
      );
      debugPrint(
          ' [PowerSync DEBUG] Total records in hc_patient_visit_detail: ${count?['cnt'] ?? 0}');

      // Check first few records
      final sample = await db.getAll(
        'SELECT id, visit_date, patient_name, status FROM hc_patient_visit_detail LIMIT 5',
      );
      debugPrint(' [PowerSync DEBUG] Sample records:');
      for (var row in sample) {
        debugPrint(
            '   - ID: ${row['id']}, Date: ${row['visit_date']}, Name: ${row['patient_name']}, Status: ${row['status']}');
      }

      // Check sync status
      final status = db.currentStatus;
      debugPrint(
          ' [PowerSync DEBUG] Sync status: connected=${status.connected}, downloading=${status.downloading}, uploading=${status.uploading}');
    } catch (e) {
      debugPrint(' [PowerSync DEBUG] Error checking database: $e');
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      throw StateError('PowerSync not initialized. Call initialize() first.');
    }
  }

  // ── Sync Recovery ────────────────────────────────────────────────

  DateTime? _lastSyncedAtSeen;
  DateTime? _stuckSince;
  DateTime? _lastReconnectTime;

  /// Monitors sync status and auto-reconnects when the checkpoint is stuck.
  /// Detects: downloading=true for >5s but lastSyncedAt never advances.
  void _setupSyncRecovery() {
    db.statusStream.listen((status) async {
      if (_debugSync) {
        debugPrint('[PowerSync STATUS] connected=${status.connected}, '
            'downloading=${status.downloading}, uploading=${status.uploading}, '
            'lastSyncedAt=${status.lastSyncedAt}');
      }

      // Check if lastSyncedAt advanced → checkpoint applied successfully
      if (status.lastSyncedAt != null &&
          status.lastSyncedAt != _lastSyncedAtSeen) {
        debugPrint('[PowerSync]  Checkpoint applied at ${status.lastSyncedAt}');
        _lastSyncedAtSeen = status.lastSyncedAt;
        _stuckSince = null; // Reset stuck timer
        return;
      }

      // Detect stuck checkpoint: connected + downloading but lastSyncedAt
      // not advancing. This is the "Could not apply checkpoint" pattern.
      if (status.connected && status.downloading && !status.uploading) {
        _stuckSince ??= DateTime.now();
        final stuckDuration = DateTime.now().difference(_stuckSince!);

        if (stuckDuration > const Duration(seconds: 5)) {
          // Cooldown: don't reconnect more than once per 10s
          if (_lastReconnectTime != null &&
              DateTime.now().difference(_lastReconnectTime!) <
                  const Duration(seconds: 10)) {
            return;
          }

          debugPrint(
              '[PowerSync] ⚠️ Checkpoint stuck for ${stuckDuration.inSeconds}s '
              '— forcing reconnect to clear internal state...');
          _stuckSince = null;
          await _reconnect();
        }
      }
    }, onError: (error) {
      // Silently handle JS interop errors on web (LegacyJavaScriptObject)
      debugPrint('[PowerSync] statusStream error (ignored): $error');
    });
  }

  /// Safely disconnect and reconnect to reset the sync stream.
  Future<void> _reconnect() async {
    try {
      _lastReconnectTime = DateTime.now();
      debugPrint('[PowerSync] Reconnecting...');
      await db.disconnect();
      await Future.delayed(const Duration(milliseconds: 500));
      await db.connect(connector: _connector);
      debugPrint('[PowerSync] Reconnected successfully ');
    } catch (e) {
      debugPrint('[PowerSync] Reconnect failed: $e');
    }
  }

  /// Full reconnect for tenant switch: disconnect, purge old tenant data
  /// from local SQLite, re-create the connector with fresh credentials
  /// (new tenant_id from StorageService), and reconnect.
  Future<void> reconnectForTenantChange(StorageService storage) async {
    if (!_initialized) return;

    try {
      debugPrint('[PowerSync] Tenant change — disconnecting...');
      await db.disconnect();

      // Purge all local data so old tenant's work orders don't linger.
      // PowerSync will re-sync the new tenant's data on reconnect.
      await db.execute('DELETE FROM hc_patient_visit_detail');
      await db.execute('DELETE FROM price_list');
      await db.execute('DELETE FROM temp_uploads');
      debugPrint('[PowerSync] Local data purged for tenant switch');

      // Re-create connector so fetchCredentials reads the new tenant_id
      _connector = BackendConnector(
        storage: storage,
        onRefreshToken: _connector.onRefreshToken,
      );

      await Future.delayed(const Duration(milliseconds: 500));
      await db.connect(connector: _connector);
      debugPrint('[PowerSync] Reconnected with new tenant credentials ✅');
    } catch (e) {
      debugPrint('[PowerSync] Tenant change reconnect failed: $e');
    }
  }

  /// Actively wait for the checkpoint to apply after CRUD drain.
  /// If the checkpoint doesn't advance within [timeout], force a reconnect.
  /// This is faster than waiting for the passive watchdog (5s detection).
  Future<void> waitForCheckpointOrReconnect({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final startLastSync = db.currentStatus.lastSyncedAt;
    debugPrint(
        '[PowerSync] Waiting for checkpoint advancement (current: $startLastSync)...');

    try {
      await db.statusStream
          .where(
              (s) => s.lastSyncedAt != null && s.lastSyncedAt != startLastSync)
          .first
          .timeout(timeout);

      debugPrint('[PowerSync]  Checkpoint advanced after CRUD drain');
    } on TimeoutException {
      debugPrint(
          '[PowerSync] ⚠️ Checkpoint didn\'t advance in ${timeout.inSeconds}s — forcing reconnect...');

      // Only reconnect if cooldown allows
      if (_lastReconnectTime == null ||
          DateTime.now().difference(_lastReconnectTime!) >
              const Duration(seconds: 10)) {
        await _reconnect();
      }
    } catch (e) {
      debugPrint('[PowerSync] waitForCheckpoint error: $e');
    }
  }

  // ── Recoverable Watch ────────────────────────────────────────────

  /// Public resilient watch — wraps db.watch() with auto-restart on error or
  /// stream end. Use this instead of raw db.watch() in ALL repositories to
  /// prevent permanent stream death from checkpoint blocking.
  Stream<List<Map<String, dynamic>>> createRecoverableWatch(
    String sql,
    List<Object?> parameters,
  ) {
    if (!_initialized) return const Stream.empty();

    StreamController<List<Map<String, dynamic>>>? controller;
    StreamSubscription? subscription;
    bool isCancelled = false;

    void startListening() {
      if (isCancelled || !_initialized) return;

      // Wrap with handleError to catch LegacyJavaScriptObject interop
      // cast failures (e.g. UpdateNotification?) at the stream pipe level,
      // before they reach the subscription's onError handler.
      subscription = db
          .watch(sql, parameters: parameters)
          .handleError((error) {
        debugPrint('[PowerSync Watch] Stream pipe error (caught): $error');
      }).listen(
        (rows) {
          if (!isCancelled) {
            controller
                ?.add(rows.map((r) => Map<String, dynamic>.from(r)).toList());
          }
        },
        onError: (error) {
          debugPrint(
              '[PowerSync Watch] Error: $error — restarting stream...');
          subscription?.cancel();
          if (!isCancelled) {
            Future.delayed(const Duration(seconds: 1), startListening);
          }
        },
        onDone: () {
          if (_debugSync)
            debugPrint(
                '[PowerSync Watch] Stream ended (checkpoint issue?) — restarting...');
          subscription?.cancel();
          if (!isCancelled) {
            Future.delayed(const Duration(seconds: 1), startListening);
          }
        },
      );
    }

    controller = StreamController<List<Map<String, dynamic>>>.broadcast(
      onListen: () {
        isCancelled = false;
        startListening();
      },
      onCancel: () {
        isCancelled = true;
        subscription?.cancel();
      },
    );

    return controller.stream;
  }

  // ── Watch Methods ───────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> watchWorkOrdersByDate(
      DateTime selectedDate) {
    final dateStr = selectedDate.toIso8601String().split('T')[0];
    return createRecoverableWatch(
      'SELECT * FROM hc_patient_visit_detail WHERE visible = 1 AND visit_date = ? ORDER BY visit_time ASC',
      [dateStr],
    );
  }

  Stream<List<Map<String, dynamic>>> watchWorkOrdersFromDate(
      DateTime startDate) {
    final startStr = startDate.toIso8601String().split('T')[0];
    final endDate = startDate.add(const Duration(days: 6));
    final endStr = endDate.toIso8601String().split('T')[0];
    return createRecoverableWatch(
      'SELECT * FROM hc_patient_visit_detail WHERE visible = 1 AND visit_date >= ? AND visit_date <= ? ORDER BY visit_date ASC, visit_time ASC',
      [startStr, endStr],
    );
  }

  Stream<List<Map<String, dynamic>>> watchTechnicianWorkOrders(String techId) {
    return createRecoverableWatch(
      'SELECT * FROM hc_patient_visit_detail WHERE assigned_id = ? AND visible = 1 ORDER BY visit_date DESC, visit_time DESC',
      [techId],
    );
  }

  // ── JSON Normalization (DISABLED) ─────────────────────────────────
  // These were used to sort JSON keys to match Postgres jsonb ordering,
  // preventing "Could not apply checkpoint" errors. No longer needed
  // because Rust sync (SyncClientImplementation.rust) handles this,
  // and _setupSyncRecovery() auto-reconnects on stuck checkpoints.
  //
  // static String _normalizeJsonForPostgres(dynamic value) {
  //   if (value is String) {
  //     try {
  //       final parsed = jsonDecode(value);
  //       return jsonEncode(_sortKeys(parsed));
  //     } catch (_) {
  //       return value;
  //     }
  //   } else if (value is Map) {
  //     return jsonEncode(_sortKeys(value));
  //   }
  //   return jsonEncode(value);
  // }
  //
  // static dynamic _sortKeys(dynamic value) {
  //   if (value is Map) {
  //     final sorted = Map<String, dynamic>.fromEntries(
  //       (value.entries.toList()
  //             ..sort((a, b) {
  //               final aKey = a.key.toString();
  //               final bKey = b.key.toString();
  //               final lenCmp = aKey.length.compareTo(bKey.length);
  //               return lenCmp != 0 ? lenCmp : aKey.compareTo(bKey);
  //             }))
  //           .map((e) => MapEntry(e.key.toString(), _sortKeys(e.value))),
  //     );
  //     return sorted;
  //   } else if (value is List) {
  //     return value.map((e) => _sortKeys(e)).toList();
  //   }
  //   return value;
  // }

  Future<void> createWorkOrder(WorkOrder order) async {
    await _ensureInitialized();
    final data = order.toMap();

    await db.execute('''
    INSERT OR REPLACE INTO hc_patient_visit_detail (
      id, tenant_id, hcpm_id, doc_id, patient_name, visit_date, visit_time,
      doctor_name, pro_id, manager_id, manager_name, assigned_id, assigned_to,
      b2b_client_id, b2b_client_name, status, server_status, 
      bill_amount, received_amount, discount_amount, doc,
      bill_number, lab_number, visible, created_by, created_at, 
      last_updated_by, last_updated_at, sync_window
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
      data['doc'] is String ? data['doc'] : jsonEncode(data['doc']),
      data['bill_number'],
      data['lab_number'],
      data['visible'],
      data['created_by'],
      data['created_at'],
      data['last_updated_by'],
      data['last_updated_at'],
      data['sync_window'] ?? 1,
    ]);
  }

  Future<bool> updateWorkOrder(
    WorkOrder workOrder, {
    Map<String, dynamic>? customDoc,
  }) async {
    await _ensureInitialized();

    try {
      final data = workOrder.toMap();
      final now = DateTime.now().toUtc().toIso8601String();
      final docToUse = customDoc != null ? jsonEncode(customDoc) : data['doc'];

      await db.execute(
        '''
      UPDATE hc_patient_visit_detail 
      SET 
        patient_name = ?, visit_date = ?, visit_time = ?, doctor_name = ?, 
        manager_id = ?, manager_name = ?, assigned_id = ?, assigned_to = ?, 
        b2b_client_id = ?, b2b_client_name = ?, 
        status = ?, server_status = ?, bill_amount = ?, received_amount = ?, 
        discount_amount = ?, doc = ?, last_updated_by = ?, last_updated_at = ?,
        sync_window = ?
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
          docToUse is String ? docToUse : jsonEncode(docToUse),
          data['last_updated_by'],
          now,
          data['sync_window'] ?? 1,
          data['id'],
        ],
      );
      return true;
    } catch (e) {
      debugPrint(' UPDATE failed: $e');
      return false;
    }
  }

  Future<void> softDeleteWorkOrder(String id, String user) async {
    await _ensureInitialized();
    final now = DateTime.now().toIso8601String();
    await db.execute(
      'UPDATE hc_patient_visit_detail SET visible = 0, last_updated_by = ?, last_updated_at = ? WHERE id = ?',
      [user, now, id],
    );
  }

  Future<void> deleteWorkOrder(String id) async {
    await _ensureInitialized();
    await db.execute('DELETE FROM hc_patient_visit_detail WHERE id = ?', [id]);
  }

  Stream<SyncStatus> watchStatus() {
    // Wrap with handleError to prevent LegacyJavaScriptObject cast
    // failures on Flutter web from crashing the stream consumer.
    return db.statusStream.handleError((error) {
      debugPrint('[PowerSync] watchStatus stream error (ignored): $error');
    });
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

  Stream<List<Map<String, dynamic>>> watchCancelledWorkOrdersByDate(
      DateTime date) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    return createRecoverableWatch(
      '''
      SELECT * FROM hc_patient_visit_detail 
      WHERE visit_date = ? 
      AND (status = 'cancelled' OR server_status = 'cancelled') 
      AND visible = 1
      ORDER BY visit_time DESC
      ''',
      [dateStr],
    );
  }

  /// Wait for the CRUD upload queue to fully drain (all local writes uploaded).
  /// Directly polls the ps_crud table instead of relying on sync status flags,
  /// because the status flag has a race condition: the local write is in the
  /// queue but PowerSync hasn't started uploadData() yet, so `uploading` is
  /// still false and the old approach returned immediately.
  Future<void> waitForSync(
      {Duration timeout = const Duration(seconds: 15)}) async {
    final deadline = DateTime.now().add(timeout);
    const pollInterval = Duration(milliseconds: 300);

    while (DateTime.now().isBefore(deadline)) {
      try {
        final result = await db.getAll('SELECT count(*) as cnt FROM ps_crud');
        final count = result.first['cnt'] as int? ?? 0;
        if (count == 0) {
          debugPrint('[PowerSync] waitForSync: CRUD queue empty ');
          return;
        }
        debugPrint('[PowerSync] waitForSync: $count CRUD entries pending...');
      } catch (e) {
        debugPrint('[PowerSync] waitForSync query error: $e');
      }
      await Future.delayed(pollInterval);
    }
    debugPrint('[PowerSync] waitForSync timed out after $timeout');
  }

  Future<List<Map<String, dynamic>>> getAllWorkOrdersForDate(
      String dateStr) async {
    final results = await db.getAll(
      '''
      SELECT * FROM hc_patient_visit_detail 
      WHERE visit_date = ? AND visible = 1
      ''',
      [dateStr],
    );

    return results.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<void> toggleRemittanceAcceptance(
      String id, bool status, String user) async {
    await _ensureInitialized();
    final timeStamp = Util.gettime();
    final actionLog = status ? "Remittance Accepted." : "Remittance Cancelled.";
    final logEntry = '$timeStamp - $user - $actionLog';
    final now = DateTime.now().toIso8601String();

    await db.writeTransaction((tx) async {
      final result = await tx.getOptional(
          'SELECT doc FROM hc_patient_visit_detail WHERE id = ?', [id]);
      if (result == null) {
        debugPrint('[PowerSync] toggleRemittance: No local record for id=$id');
        return;
      }

      final docMap = jsonDecode(result['doc'] as String);

      docMap['accept_remittance'] = status;

      List<dynamic> timeline = List.from(docMap['time_line'] ?? []);
      timeline.add(logEntry);
      docMap['time_line'] = timeline;

      docMap['updated_at'] = now;

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
