import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:powersync/powersync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/powersync/powersync_service.dart';
import 'package:anderson_crm_flutter/services/storage_service.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';

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

  StreamSubscription<SyncStatus>? _statusSubscription;
  SyncStatus? _syncStatus;

  bool _isInitializing = true;
  Completer<void>? _initCompleter;

  TechnicianWorkOrderRepository({required this.storage}) {
    debugPrint('🏭 TechnicianWorkOrderRepository CONSTRUCTOR called');
  }

  bool get isInitializing => _isInitializing;
  bool get isConnected => _syncStatus?.connected ?? false;
  bool get isSyncing =>
      (_syncStatus?.downloading ?? false) || (_syncStatus?.uploading ?? false);
  bool get hasPendingUploads => _syncStatus?.uploading ?? false;
  SyncStatus? get syncStatus => _syncStatus;

  Future<void> initialize() async {
    if (!_isInitializing) return;
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }

    debugPrint('🚀 TechnicianWorkOrderRepository.initialize() START');
    _initCompleter = Completer<void>();

    Future.microtask(() async {
      await _initializeInternal();
    });

    return _initCompleter!.future;
  }

  Future<void> _initializeInternal() async {
    try {
      await _powerSync.initialize(storage);

      _statusSubscription = _powerSync.watchStatus().listen((status) {
        _syncStatus = status;
      });

      _isInitializing = false;
      _initCompleter?.complete();
      debugPrint('✅ TechnicianWorkOrderRepository.initialize() COMPLETE');
    } catch (e) {
      debugPrint('❌ TechnicianWorkOrderRepository.initialize() FAILED: $e');
      _isInitializing = false;
      _initCompleter?.completeError(e);
    }
  }

  Future<void> ensureInitialized() async {
    if (_isInitializing && _initCompleter != null) {
      await _initCompleter!.future;
    }
  }

  Stream<List<WorkOrder>> watchTechnicianWorkOrders(String techId) {
    return _powerSync
        .watchTechnicianWorkOrders(techId)
        .asyncMap((rawRows) async {
      debugPrint(
          '📊 Parsing ${rawRows.length} technician work orders in isolate...');
      return await compute(_parseWorkOrdersIsolate, rawRows);
    });
  }

  Future<bool> createWorkOrder(WorkOrder order) async {
    try {
      await _powerSync.createWorkOrder(order);
      return true;
    } catch (e) {
      debugPrint('❌ Create failed: $e');
      return false;
    }
  }

  Future<bool> updateWorkOrder(WorkOrder order,
      {Map<String, dynamic>? customDoc}) async {
    try {
      return await _powerSync.updateWorkOrder(order, customDoc: customDoc);
    } catch (e) {
      debugPrint('❌ Update failed: $e');
      return false;
    }
  }

  Future<bool> softDeleteWorkOrder(int id, String user) async {
    try {
      await _powerSync.softDeleteWorkOrder(id, user);
      return true;
    } catch (e) {
      debugPrint('❌ Soft delete failed: $e');
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

  void dispose() {
    _statusSubscription?.cancel();
  }
}

final technicianWorkOrderRepositoryProvider =
    Provider<TechnicianWorkOrderRepository>((ref) {
  final storage = ref.read(storageServiceProvider);
  final repo = TechnicianWorkOrderRepository(storage: storage);
  ref.onDispose(() => repo.dispose());
  return repo;
});
