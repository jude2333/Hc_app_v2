import 'dart:async';
import 'package:anderson_crm_flutter/services/storage_service.dart';
import 'package:flutter/foundation.dart'; // For compute
import 'package:flutter/material.dart';
import 'package:powersync/powersync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/work_order.dart';
// import '../powersync/servicess/powersync_service.dart';
import 'package:anderson_crm_flutter/powersync/powersync_service.dart';
// import '../services/storage_service.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';

// ✅ Isolate function for parsing work orders (runs in background)
List<WorkOrder> _parseWorkOrdersIsolate(List<dynamic> rows) {
  return rows.map((row) {
    final data = row as Map<String, dynamic>;
    return WorkOrder.fromRow(data);
  }).toList();
}

// ✅ Isolate function for filtering work orders using pre-computed searchableText
List<WorkOrder> _filterWorkOrdersIsolate(_FilterParams params) {
  if (params.query.isEmpty) return params.orders;
  final term = params.query.toLowerCase();

  return params.orders.where((wo) {
    // Use pre-computed searchableText for fast filtering
    return wo.searchableText.contains(term);
  }).toList();
}

// Helper class to pass multiple params to isolate
class _FilterParams {
  final List<WorkOrder> orders;
  final String query;
  const _FilterParams(this.orders, this.query);
}

class WorkOrderProvider with ChangeNotifier {
  final PowerSyncService _powerSync = PowerSyncService.instance;
  final StorageService storage;

  WorkOrderProvider({required this.storage}) {
    debugPrint('🏭 WorkOrderProvider CONSTRUCTOR called');
  }

  List<WorkOrder> _workOrders = [];
  SyncStatus? _syncStatus;
  bool _isInitializing = true;
  bool _isLoading = false;
  String? _errorMessage;

  // ✅ FIX: Track initialization completion
  Completer<void>? _initCompleter;

  StreamSubscription<List<WorkOrder>>? _ordersSubscription;
  StreamSubscription<SyncStatus>? _statusSubscription;

  List<WorkOrder> get workOrders => _workOrders;
  bool get isInitializing => _isInitializing;
  bool get isLoading => _isLoading;
  bool get isConnected => _syncStatus?.connected ?? false;
  bool get isSyncing =>
      (_syncStatus?.downloading ?? false) || (_syncStatus?.uploading ?? false);
  bool get hasPendingUploads => _syncStatus?.uploading ?? false;
  String? get errorMessage => _errorMessage;
  SyncStatus? get syncStatus => _syncStatus;

  // ✅ OPTIMIZATION: Non-blocking initialization with tracking
  Future<void> initialize() async {
    // If already initialized, return immediately
    if (!_isInitializing) return;

    // If initialization is in progress, wait for it
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }

    debugPrint('🚀 WorkOrderProvider.initialize() START');

    _initCompleter = Completer<void>();

    // Set loading state immediately so UI can show skeleton
    _isLoading = true;
    notifyListeners();

    // ✅ Use microtask to let UI render first, then await internally
    Future.microtask(() async {
      await _initializeInternal();
    });

    return _initCompleter!.future;
  }

  // Internal initialization (runs in background)
  Future<void> _initializeInternal() async {
    try {
      await _powerSync.initialize(storage);

      // Sync Status Subscription
      _statusSubscription = _powerSync.watchStatus().listen((status) {
        _syncStatus = status;
        notifyListeners();
      });

      _isInitializing = false;
      _isLoading = false;
      _initCompleter?.complete();
      notifyListeners();
    } catch (e) {
      debugPrint('❌ WorkOrderProvider.initialize() FAILED: $e');
      _errorMessage = 'Initialization failed: $e';
      _isInitializing = false;
      _isLoading = false;
      _initCompleter?.completeError(e);
      notifyListeners();
    }
  }

  // ✅ FIX: Ensure initialization is complete before loading
  Future<void> _ensureInitialized() async {
    if (_isInitializing && _initCompleter != null) {
      await _initCompleter!.future;
    }
  }

  Future<void> loadWorkOrdersByDate(DateTime selectedDate) async {
    debugPrint('📅 Loading orders for: $selectedDate');

    // ✅ FIX: Wait for initialization before accessing PowerSync
    await _ensureInitialized();

    try {
      await _ordersSubscription?.cancel();

      _ordersSubscription = _powerSync
          .watchWorkOrdersByDate(selectedDate)
          .asyncMap((rawRows) async {
        return await compute(_parseWorkOrdersIsolate, rawRows);
      }).listen(
        (orders) {
          debugPrint(
              '✅ UI notified with ${orders.length} work orders (via Isolate)');
          _workOrders = orders;
          _errorMessage = null;
          notifyListeners();
        },
        onError: (error) {
          debugPrint('❌ Stream Error: $error');
          _errorMessage = 'Failed to load: $error';
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('❌ loadWorkOrdersByDate failed: $e');
      _errorMessage = 'Error: $e';
      notifyListeners();
    }
  }

  Future<void> loadTechnicianWorkOrders(String techId) async {
    debugPrint('👨‍🔧 Loading technician orders: $techId');

    // ✅ FIX: Wait for initialization before accessing PowerSync
    await _ensureInitialized();

    try {
      await _ordersSubscription?.cancel();

      _ordersSubscription = _powerSync
          .watchTechnicianWorkOrders(techId)
          .asyncMap((rawRows) async {
        // isolotate optimization
        return await compute(_parseWorkOrdersIsolate, rawRows);
      }).listen(
        (orders) {
          debugPrint('✅ Technician UI notified with ${orders.length} orders');
          _workOrders = orders;
          _errorMessage = null;
          notifyListeners();
        },
        onError: (error) {
          debugPrint('❌ Technician Stream Error: $error');
          _errorMessage = 'Failed to load: $error';
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('❌ loadTechnicianWorkOrders failed: $e');
      _errorMessage = 'Error: $e';
      notifyListeners();
    }
  }

  // ---------------- CRUD OPERATIONS ----------------

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

  // ✅ OPTIMIZED: Isolate-based search using pre-computed searchableText
  Future<List<WorkOrder>> searchWorkOrdersAsync(String query) async {
    if (query.isEmpty) return workOrders;
    return await compute(
        _filterWorkOrdersIsolate, _FilterParams(workOrders, query));
  }

  // Sync version for small lists (kept for compatibility)
  List<WorkOrder> searchWorkOrders(String query) {
    if (query.isEmpty) return workOrders;
    final q = query.toLowerCase();
    return workOrders.where((o) => o.searchableText.contains(q)).toList();
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    _statusSubscription?.cancel();
    super.dispose();
  }
}

final workOrderProvider = ChangeNotifierProvider<WorkOrderProvider>((ref) {
  final storage = ref.read(storageServiceProvider);
  return WorkOrderProvider(storage: storage);
});
