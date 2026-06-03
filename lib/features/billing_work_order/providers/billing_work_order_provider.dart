import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:powersync/powersync.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/providers/couch_db_provider.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import 'package:anderson_crm_flutter/powersync/powersync_service.dart';
import '../data/billing_work_order_repository.dart';

@immutable
class BillingWorkOrderState {
  final bool isLoading;
  final bool isInitializing;
  final List<WorkOrder> orders;
  final String? errorMessage;
  final String selectedTab;

  const BillingWorkOrderState({
    this.isLoading = false,
    this.isInitializing = true,
    this.orders = const [],
    this.errorMessage,
    this.selectedTab = 'unbilled',
  });

  BillingWorkOrderState copyWith({
    bool? isLoading,
    bool? isInitializing,
    List<WorkOrder>? orders,
    String? errorMessage,
    String? selectedTab,
    bool clearError = false,
  }) {
    return BillingWorkOrderState(
      isLoading: isLoading ?? this.isLoading,
      isInitializing: isInitializing ?? this.isInitializing,
      orders: orders ?? this.orders,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      selectedTab: selectedTab ?? this.selectedTab,
    );
  }
}

class BillingWorkOrderNotifier
    extends AutoDisposeNotifier<BillingWorkOrderState> {
  BillingWorkOrderRepository? _repository;
  bool _powerSyncInitStarted = false;
  StreamSubscription<List<WorkOrder>>? _ordersSubscription;

  @override
  BillingWorkOrderState build() {
    debugPrint('BillingWorkOrderNotifier build() called');

    ref.onDispose(() {
      debugPrint('BillingWorkOrderNotifier DISPOSED - Closing stream!');
      _ordersSubscription?.cancel();
    });

    return const BillingWorkOrderState();
  }

  BillingWorkOrderRepository? _getRepository() {
    if (_repository != null) return _repository;

    try {
      if (!PowerSyncService.instance.isInitialized) {
        debugPrint('[BillingProvider] PowerSync not initialized yet');
        return null;
      }

      final db = PowerSyncService.instance.db;
      final couchClient = ref.read(couchDbClientProvider);
      final storage = ref.read(storageRepositoryProvider);
      _repository = BillingWorkOrderRepository(db, couchClient, storage);
      return _repository;
    } catch (e) {
      debugPrint('[BillingProvider] Error creating repository: $e');
      return null;
    }
  }

  Future<void> _initializePowerSync() async {
    if (PowerSyncService.instance.isInitialized) return;
    if (_powerSyncInitStarted) return;

    _powerSyncInitStarted = true;
    debugPrint('[BillingProvider] Initializing PowerSync...');

    try {
      final storage = ref.read(storageServiceProvider);
      await PowerSyncService.instance.initialize(storage);
      debugPrint('[BillingProvider] PowerSync initialized successfully');
    } catch (e) {
      debugPrint('[BillingProvider] PowerSync init error: $e');
      _powerSyncInitStarted = false;
      rethrow;
    }
  }

  Future<void> initialize() async {
    state = state.copyWith(isInitializing: true);
    try {
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

  Future<void> loadUnbilled() async {
    final repo = _getRepository();
    if (repo == null) {
      try {
        await _initializePowerSync();

        final repoRetry = _getRepository();
        if (repoRetry == null) {
          state = state.copyWith(
            isLoading: false,
            isInitializing: false,
            errorMessage: 'PowerSync not ready after initialization',
          );
          return;
        }
        return _startUnbilledStream(repoRetry);
      } catch (e) {
        state = state.copyWith(
          isLoading: false,
          isInitializing: false,
          errorMessage: 'PowerSync initialization failed: $e',
        );
        return;
      }
    }

    return _startUnbilledStream(repo);
  }

  Future<void> _startUnbilledStream(BillingWorkOrderRepository repo) async {
    await _ordersSubscription?.cancel();

    state = state.copyWith(isLoading: true, selectedTab: 'unbilled');

    _ordersSubscription = repo.watchUnbilledOrders().listen(
      (orders) {
        state = state.copyWith(
          isLoading: false,
          orders: orders,
          clearError: true,
        );
      },
      onError: (error) {
        debugPrint('[Billing] Unbilled stream error: $error');
        state = state.copyWith(
          isLoading: false,
          errorMessage: error.toString(),
        );
      },
    );
  }

  Future<void> loadBilled() async {
    final repo = _getRepository();
    if (repo == null) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'PowerSync not ready. Please wait...',
      );
      return;
    }

    await _ordersSubscription?.cancel();

    state = state.copyWith(isLoading: true, selectedTab: 'billed');

    _ordersSubscription = repo.watchBilledOrders().listen(
      (orders) {
        state = state.copyWith(
          isLoading: false,
          orders: orders,
          clearError: true,
        );
      },
      onError: (error) {
        debugPrint('[Billing] Billed stream error: $error');
        state = state.copyWith(
          isLoading: false,
          errorMessage: error.toString(),
        );
      },
    );
  }

  Future<void> _syncAfterMutation() async {
    try {
      await PowerSyncService.instance
          .waitForSync(timeout: const Duration(seconds: 10));
      await PowerSyncService.instance
          .waitForCheckpointOrReconnect(timeout: const Duration(seconds: 3));
    } catch (e) {
      debugPrint('[Billing] syncAfterMutation failed: $e');
    }
  }

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

      await _syncAfterMutation();

      return 'OK';
    } catch (e) {
      debugPrint('[BillingProvider] Error billing: $e');
      return 'Error: $e';
    }
  }

  Future<void> refresh() async {
    if (state.selectedTab == 'unbilled') {
      await loadUnbilled();
    } else {
      await loadBilled();
    }
  }

  Future<String> sendOrder(WorkOrder workOrder) async {
    final repo = _getRepository();
    if (repo == null) return 'Error: PowerSync not ready';

    try {
      final storage = ref.read(storageServiceProvider);
      final createdBy = storage.getFromSession('logged_in_emp_id');

      int age = 0;
      try {
        age = int.parse(workOrder.age);
      } catch (_) {
        age = 0;
      }

      final data = {
        'patient': {
          'firstName': workOrder.patientName,
          'lastName': 'null',
          'age': age,
          'period': 3,
          'mobileNumber': workOrder.mobile,
          'addressLine1': workOrder.address,
          'postalCode': workOrder.pincode,
        },
        'clientName': 'null',
        'clientId': 0,
        'investigations': workOrder.testItems
            .map((test) => ({
                  'investigationId': test['invest_id'],
                  'investigationName': test['invest_name'],
                  'amount': test['base_cost'],
                  'discount': 0,
                }))
            .toList(),
        'payments': [
          {'amount': double.tryParse(workOrder.amountReceived) ?? 0},
        ],
        'createdBy': createdBy,
        'remarks': workOrder.remarks,
      };

      debugPrint('[BillingProvider] Sending order: $data');

      final result = await repo.sendOrderToApi(
        workOrder: workOrder,
        payload: data,
      );

      if (result == 'SUCCESS') {
        await refresh();
        return 'OK';
      } else {
        return 'Failed to send data';
      }
    } catch (e) {
      debugPrint('[BillingProvider] Error sending: $e');
      return 'Error: $e';
    }
  }
}

final billingWorkOrderProvider = AutoDisposeNotifierProvider<
    BillingWorkOrderNotifier, BillingWorkOrderState>(
  BillingWorkOrderNotifier.new,
);

final billingSyncStatusProvider = StreamProvider<SyncStatus>((ref) {
  return PowerSyncService.instance.watchStatus();
});

final billingSearchPod = AutoDisposeStateProvider<String>((_) => '');
final billingSortColumnPod = AutoDisposeStateProvider<String>((_) => 'date');
final billingSortAscendingPod = AutoDisposeStateProvider<bool>((_) => false);

final billingFilteredOrdersPod = AutoDisposeProvider<List<WorkOrder>>((ref) {
  final orders = ref.watch(
    billingWorkOrderProvider.select((s) => s.orders),
  );
  final search = ref.watch(billingSearchPod);
  final sortCol = ref.watch(billingSortColumnPod);
  final sortAsc = ref.watch(billingSortAscendingPod);

  List<WorkOrder> filtered = search.isEmpty
      ? List.from(orders)
      : orders.where((wo) {
          final term = search.toLowerCase();
          return wo.searchableText.contains(term);
        }).toList();

  filtered.sort((a, b) {
    int cmp = 0;
    switch (sortCol) {
      case 'name':
        cmp = a.patientName.compareTo(b.patientName);
        break;
      case 'total':
        cmp = a.calculatedTotal.compareTo(b.calculatedTotal);
        break;
      case 'date':
      default:
        cmp = a.visitDate.compareTo(b.visitDate);
        if (cmp == 0) cmp = a.visitTime.compareTo(b.visitTime);
        break;
    }
    return sortAsc ? cmp : -cmp;
  });

  return filtered;
});
