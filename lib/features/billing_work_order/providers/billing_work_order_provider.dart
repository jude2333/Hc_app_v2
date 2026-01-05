import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/providers/couch_db_provider.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import 'package:anderson_crm_flutter/powersync/powersync_service.dart';
import '../data/billing_work_order_repository.dart';

/// State for billing work orders
@immutable
class BillingWorkOrderState {
  final bool isLoading;
  final bool isInitializing;
  final List<WorkOrder> orders;
  final String? errorMessage;
  final String selectedTab; // 'unbilled' | 'billed'
  final String searchQuery;

  const BillingWorkOrderState({
    this.isLoading = false,
    this.isInitializing = true,
    this.orders = const [],
    this.errorMessage,
    this.selectedTab = 'unbilled',
    this.searchQuery = '',
  });

  BillingWorkOrderState copyWith({
    bool? isLoading,
    bool? isInitializing,
    List<WorkOrder>? orders,
    String? errorMessage,
    String? selectedTab,
    String? searchQuery,
  }) {
    return BillingWorkOrderState(
      isLoading: isLoading ?? this.isLoading,
      isInitializing: isInitializing ?? this.isInitializing,
      orders: orders ?? this.orders,
      errorMessage: errorMessage,
      selectedTab: selectedTab ?? this.selectedTab,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  /// Filtered orders based on search query
  List<WorkOrder> get filteredOrders {
    if (searchQuery.isEmpty) return orders;
    final term = searchQuery.toLowerCase();
    return orders.where((wo) => wo.searchableText.contains(term)).toList();
  }
}

/// Provider for billing work orders
class BillingWorkOrderNotifier extends StateNotifier<BillingWorkOrderState> {
  final Ref _ref;
  BillingWorkOrderRepository? _repository;
  bool _powerSyncInitStarted = false;

  BillingWorkOrderNotifier(this._ref) : super(const BillingWorkOrderState());

  /// Lazily get or create the repository (only when PowerSync is ready)
  BillingWorkOrderRepository? _getRepository() {
    if (_repository != null) return _repository;

    try {
      // Only access db when actually needed (not at build time)
      if (!PowerSyncService.instance.isInitialized) {
        debugPrint('[BillingProvider] PowerSync not initialized yet');
        return null;
      }

      final db = PowerSyncService.instance.db;
      final couchClient = _ref.read(couchDbClientProvider);
      _repository = BillingWorkOrderRepository(db, couchClient);
      return _repository;
    } catch (e) {
      debugPrint('[BillingProvider] Error creating repository: $e');
      return null;
    }
  }

  /// Initialize PowerSync if not already initialized
  Future<void> _initializePowerSync() async {
    if (PowerSyncService.instance.isInitialized) return;
    if (_powerSyncInitStarted) return; // Prevent multiple init attempts

    _powerSyncInitStarted = true;
    debugPrint('[BillingProvider] Initializing PowerSync...');

    try {
      final storage = _ref.read(storageServiceProvider);
      await PowerSyncService.instance.initialize(storage);
      debugPrint('[BillingProvider] PowerSync initialized successfully');
    } catch (e) {
      debugPrint('[BillingProvider] PowerSync init error: $e');
      _powerSyncInitStarted = false; // Allow retry
      rethrow;
    }
  }

  /// Initialize and load unbilled orders
  Future<void> initialize() async {
    state = state.copyWith(isInitializing: true);
    try {
      // Initialize PowerSync directly (like WorkOrderProvider does)
      await _initializePowerSync();

      await loadUnbilled();
    } catch (e) {
      debugPrint('[BillingProvider] Initialize error: $e');
      state = state.copyWith(
        isInitializing: false,
        errorMessage: 'Initialization failed: $e',
      );
    } finally {
      state = state.copyWith(isInitializing: false);
    }
  }

  /// Load unbilled orders (Finished + Received)
  Future<void> loadUnbilled() async {
    final repo = _getRepository();
    if (repo == null) {
      // PowerSync not ready - try initializing first
      try {
        await _initializePowerSync();
        return loadUnbilled(); // Retry after init
      } catch (e) {
        state = state.copyWith(
          isLoading: false,
          isInitializing: false,
          errorMessage: 'PowerSync initialization failed: $e',
        );
        return;
      }
    }

    state = state.copyWith(isLoading: true, selectedTab: 'unbilled');
    try {
      final orders = await repo.getUnbilledOrders();
      state = state.copyWith(
        isLoading: false,
        orders: orders,
        errorMessage: null,
      );
      debugPrint('[BillingProvider] Loaded ${orders.length} unbilled orders');
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      debugPrint('[BillingProvider] Error loading unbilled: $e');
    }
  }

  /// Load billed orders (Finished + Billed)
  Future<void> loadBilled() async {
    final repo = _getRepository();
    if (repo == null) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'PowerSync not ready. Please wait...',
      );
      return;
    }

    state = state.copyWith(isLoading: true, selectedTab: 'billed');
    try {
      final orders = await repo.getBilledOrders();
      state = state.copyWith(
        isLoading: false,
        orders: orders,
        errorMessage: null,
      );
      debugPrint('[BillingProvider] Loaded ${orders.length} billed orders');
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      debugPrint('[BillingProvider] Error loading billed: $e');
    }
  }

  /// Register billing for a work order
  Future<String> registerBill({
    required WorkOrder workOrder,
    required String billNumber,
    required String labNumber,
  }) async {
    final repo = _getRepository();
    if (repo == null) return 'Error: PowerSync not ready';

    try {
      await repo.billOrder(
        workOrder: workOrder,
        billNumber: billNumber,
        labNumber: labNumber,
      );

      // Reload current tab
      if (state.selectedTab == 'unbilled') {
        await loadUnbilled();
      } else {
        await loadBilled();
      }

      return 'OK';
    } catch (e) {
      debugPrint('[BillingProvider] Error billing: $e');
      return 'Error: $e';
    }
  }

  /// Update search query
  void search(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Clear search
  void clearSearch() {
    state = state.copyWith(searchQuery: '');
  }

  /// Refresh current tab
  Future<void> refresh() async {
    if (state.selectedTab == 'unbilled') {
      await loadUnbilled();
    } else {
      await loadBilled();
    }
  }
}

/// Provider instance - doesn't access db at build time
final billingWorkOrderProvider =
    StateNotifierProvider<BillingWorkOrderNotifier, BillingWorkOrderState>(
        (ref) {
  return BillingWorkOrderNotifier(ref);
});
