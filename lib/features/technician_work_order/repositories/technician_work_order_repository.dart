import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:powersync/powersync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/powersync/powersync_service.dart';
import 'package:anderson_crm_flutter/services/storage_service.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import 'package:anderson_crm_flutter/services/postgresService.dart';

List<WorkOrder> _parseWorkOrdersIsolate(List<dynamic> rows) {
  return rows.map((row) {
    final data = row as Map<String, dynamic>;
    return WorkOrder.fromRow(data);
  }).toList();
}

List<WorkOrder> _filterWorkOrdersIsolate(_FilterParams params) {
  if (params.query.isEmpty) return params.orders;
  final term = params.query.toLowerCase();

  return params.orders.where((wo) {
    return wo.searchableText.contains(term);
  }).toList();
}

class _FilterParams {
  final List<WorkOrder> orders;
  final String query;
  const _FilterParams(this.orders, this.query);
}

class TechnicianWorkOrderRepository {
  final PowerSyncService _powerSync = PowerSyncService.instance;
  final StorageService storage;

  final PostgresService postgresService;

  bool _isInitializing = true;
  Completer<void>? _initCompleter;

  TechnicianWorkOrderRepository({
    required this.storage,
    required this.postgresService,
  }) {
    debugPrint(' TechnicianWorkOrderRepository CONSTRUCTOR called');
  }

  bool get isInitializing => _isInitializing;
  Stream<SyncStatus> watchSyncStatus() {
    return _powerSync.watchStatus();
  }

  Future<void> initialize() async {
    if (!_isInitializing) return;
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }

    debugPrint(' TechnicianWorkOrderRepository.initialize() START');
    _initCompleter = Completer<void>();

    Future.microtask(() async {
      await _initializeInternal();
    });

    return _initCompleter!.future;
  }

  Future<void> _initializeInternal() async {
    try {
      await _powerSync.initialize(
        storage,
        onRefreshToken: () async {
          debugPrint(' TechnicianWorkOrderRepository calling refreshToken...');
          await postgresService.refreshToken();
        },
      );

      _isInitializing = false;
      _initCompleter?.complete();
      debugPrint(' TechnicianWorkOrderRepository.initialize() COMPLETE');
    } catch (e) {
      debugPrint(' TechnicianWorkOrderRepository.initialize() FAILED: $e');
      _isInitializing = false;
      _initCompleter?.completeError(e);
    }
  }

  Future<void> ensureInitialized() async {
    if (_isInitializing && _initCompleter != null) {
      await _initCompleter!.future;
    }
  }

  Future<void> waitForSync(
      {Duration timeout = const Duration(seconds: 10)}) async {
    await ensureInitialized();
    await _powerSync.waitForSync(timeout: timeout);
  }

  Future<void> waitForCheckpointOrReconnect(
      {Duration timeout = const Duration(seconds: 3)}) async {
    await _powerSync.waitForCheckpointOrReconnect(timeout: timeout);
  }

  Stream<List<WorkOrder>> watchTechnicianWorkOrders(String techId) {
    return _powerSync
        .watchTechnicianWorkOrders(techId)
        .asyncMap((rawRows) async {
      try {
        return await compute(_parseWorkOrdersIsolate, rawRows);
      } catch (e) {
        debugPrint('[TechRepo] Error parsing work orders: $e');
        return <WorkOrder>[];
      }
    });
  }

  Future<bool> createWorkOrder(WorkOrder order) async {
    try {
      await _powerSync.createWorkOrder(order);
      return true;
    } catch (e) {
      debugPrint(' Create failed: $e');
      return false;
    }
  }

  Future<bool> updateWorkOrder(WorkOrder order,
      {Map<String, dynamic>? customDoc}) async {
    try {
      return await _powerSync.updateWorkOrder(order, customDoc: customDoc);
    } catch (e) {
      debugPrint(' Update failed: $e');
      return false;
    }
  }

  Future<bool> softDeleteWorkOrder(String id, String user) async {
    try {
      await _powerSync.softDeleteWorkOrder(id, user);
      return true;
    } catch (e) {
      debugPrint(' Soft delete failed: $e');
      return false;
    }
  }

  Future<List<WorkOrder>> searchWorkOrdersAsync(
      List<WorkOrder> orders, String query) async {
    if (query.isEmpty) return orders;
    return await compute(
        _filterWorkOrdersIsolate, _FilterParams(orders, query));
  }

  List<WorkOrder> searchWorkOrders(List<WorkOrder> orders, String query) {
    if (query.isEmpty) return orders;
    final q = query.toLowerCase();
    return orders.where((o) => o.searchableText.contains(q)).toList();
  }

  Future<List<Map<String, dynamic>>> getDailyOrders(
      String techId, String dateStr) async {
    return await _powerSync.getTechnicianDailyOrders(techId, dateStr);
  }

  void dispose() {}
}

final technicianWorkOrderRepositoryProvider =
    Provider<TechnicianWorkOrderRepository>((ref) {
  final storage = ref.read(storageServiceProvider);
  final postgresService = ref.read(postgresServiceProvider);
  final repo = TechnicianWorkOrderRepository(
    storage: storage,
    postgresService: postgresService,
  );
  ref.onDispose(() => repo.dispose());
  return repo;
});
