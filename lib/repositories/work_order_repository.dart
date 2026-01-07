import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:powersync/powersync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/powersync/powersync_service.dart';
import 'package:anderson_crm_flutter/services/storage_service.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';

/// Isolate function for parsing work orders (runs in background)
List<WorkOrder> _parseWorkOrdersIsolate(List<dynamic> rows) {
  return rows.map((row) {
    final data = row as Map<String, dynamic>;
    return WorkOrder.fromRow(data);
  }).toList();
}

/// Isolate function for filtering work orders using pre-computed searchableText
List<WorkOrder> _filterWorkOrdersIsolate(_FilterParams params) {
  if (params.query.isEmpty) return params.orders;
  final term = params.query.toLowerCase();

  return params.orders.where((wo) {
    return wo.searchableText.contains(term);
  }).toList();
}

/// Helper class to pass multiple params to isolate
class _FilterParams {
  final List<WorkOrder> orders;
  final String query;
  const _FilterParams(this.orders, this.query);
}

/// Shared repository for work order data operations.
/// Contains all performance optimizations: isolates, non-blocking init, caching.
/// Used by both ManagerWorkOrderProvider and TechnicianWorkOrderProvider.
class WorkOrderRepository {
  final PowerSyncService _powerSync = PowerSyncService.instance;
  final StorageService storage;

  StreamSubscription<SyncStatus>? _statusSubscription;
  SyncStatus? _syncStatus;

  bool _isInitializing = true;
  Completer<void>? _initCompleter;

  WorkOrderRepository({required this.storage}) {
    debugPrint('🏭 WorkOrderRepository CONSTRUCTOR called');
  }

  // Getters
  bool get isInitializing => _isInitializing;
  bool get isConnected => _syncStatus?.connected ?? false;
  bool get isSyncing =>
      (_syncStatus?.downloading ?? false) || (_syncStatus?.uploading ?? false);
  bool get hasPendingUploads => _syncStatus?.uploading ?? false;
  SyncStatus? get syncStatus => _syncStatus;

  /// Non-blocking initialization with tracking
  Future<void> initialize() async {
    if (!_isInitializing) return;
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }

    debugPrint('🚀 WorkOrderRepository.initialize() START');
    _initCompleter = Completer<void>();

    Future.microtask(() async {
      await _initializeInternal();
    });

    return _initCompleter!.future;
  }

  Future<void> _initializeInternal() async {
    try {
      await _powerSync.initialize(storage);

      // Sync Status Subscription
      _statusSubscription = _powerSync.watchStatus().listen((status) {
        _syncStatus = status;
      });

      _isInitializing = false;
      _initCompleter?.complete();
    } catch (e) {
      debugPrint('❌ WorkOrderRepository.initialize() FAILED: $e');
      _isInitializing = false;
      _initCompleter?.completeError(e);
    }
  }

  /// Ensure initialization is complete before data operations
  Future<void> ensureInitialized() async {
    if (_isInitializing && _initCompleter != null) {
      await _initCompleter!.future;
    }
  }

  /// Watch work orders by date with isolate-based parsing
  Stream<List<WorkOrder>> watchWorkOrdersByDate(DateTime date) {
    return _powerSync.watchWorkOrdersByDate(date).asyncMap((rawRows) async {
      return await compute(_parseWorkOrdersIsolate, rawRows);
    });
  }

  /// Watch technician work orders with isolate-based parsing
  Stream<List<WorkOrder>> watchTechnicianWorkOrders(String techId) {
    return _powerSync
        .watchTechnicianWorkOrders(techId)
        .asyncMap((rawRows) async {
      return await compute(_parseWorkOrdersIsolate, rawRows);
    });
  }

  // ==================== CRUD OPERATIONS ====================

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

  Future<bool> deleteWorkOrder(int id) async {
    try {
      await _powerSync.deleteWorkOrder(id);
      return true;
    } catch (e) {
      debugPrint('❌ Delete failed: $e');
      return false;
    }
  }

  // ==================== SEARCH ====================

  /// Isolate-based search using pre-computed searchableText
  Future<List<WorkOrder>> searchWorkOrdersAsync(
      List<WorkOrder> orders, String query) async {
    if (query.isEmpty) return orders;
    return await compute(
        _filterWorkOrdersIsolate, _FilterParams(orders, query));
  }

  /// Sync version for small lists
  List<WorkOrder> searchWorkOrders(List<WorkOrder> orders, String query) {
    if (query.isEmpty) return orders;
    final q = query.toLowerCase();
    return orders.where((o) => o.searchableText.contains(q)).toList();
  }

  void dispose() {
    _statusSubscription?.cancel();
  }
}

// ==================== PROVIDERS ====================

final workOrderRepositoryProvider = Provider<WorkOrderRepository>((ref) {
  final storage = ref.read(storageServiceProvider);
  final repo = WorkOrderRepository(storage: storage);
  ref.onDispose(() => repo.dispose());
  return repo;
});
