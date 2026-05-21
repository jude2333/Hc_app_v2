import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:powersync/powersync.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/config/settings.dart';
import '../repositories/manager_work_order_repository.dart';

// ---------------------------------------------------------------------------
// Immutable state class — enables select() for targeted rebuilds
// ---------------------------------------------------------------------------
@immutable
class ManagerWOState {
  final List<WorkOrder> workOrders;
  final bool isLoading;
  final bool isInitializing;
  final String? errorMessage;
  final DateTime? currentDate;

  const ManagerWOState({
    this.workOrders = const [],
    this.isLoading = false,
    this.isInitializing = true,
    this.errorMessage,
    this.currentDate,
  });

  ManagerWOState copyWith({
    List<WorkOrder>? workOrders,
    bool? isLoading,
    bool? isInitializing,
    String? errorMessage,
    DateTime? currentDate,
    bool clearError = false,
  }) {
    return ManagerWOState(
      workOrders: workOrders ?? this.workOrders,
      isLoading: isLoading ?? this.isLoading,
      isInitializing: isInitializing ?? this.isInitializing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      currentDate: currentDate ?? this.currentDate,
    );
  }
}

// ---------------------------------------------------------------------------
// AutoDispose Notifier — disposes stream on navigation away, restarts on return
// ---------------------------------------------------------------------------
class ManagerWONotifier extends AutoDisposeNotifier<ManagerWOState> {
  late final ManagerWorkOrderRepository _repo;
  StreamSubscription<List<WorkOrder>>? _ordersSubscription;

  @override
  ManagerWOState build() {
    _repo = ref.watch(managerWorkOrderRepositoryProvider);
    debugPrint('ManagerWONotifier build() called');

    ref.onDispose(() {
      debugPrint('ManagerWONotifier DISPOSED - Closing stream!');
      _ordersSubscription?.cancel();
    });

    return const ManagerWOState();
  }

  Future<void> initialize() async {
    state = state.copyWith(isLoading: true);
    await _repo.initialize();
    state = state.copyWith(isLoading: false, isInitializing: false);
  }

  /// After a local mutation, wait for the CRUD queue to drain,
  /// then do an immediate one-shot query so the UI is up-to-date.
  /// The recoverable watch streams in PowerSyncService will handle
  /// catching any subsequent updates automatically.
  Future<void> syncAfterMutation() async {
    if (state.currentDate == null) return;
    debugPrint('[Manager] syncAfterMutation — waiting for CRUD drain...');
    try {
      // Step 1: Wait for all pending writes to upload.
      await _repo.waitForSync(timeout: const Duration(seconds: 10));
      debugPrint('[Manager] syncAfterMutation — CRUD queue drained ✅');

      // Step 2: Actively wait for checkpoint to apply (or force reconnect).
      // This ensures the server echo is applied before the one-shot query.
      await _repo.waitForCheckpointOrReconnect(
          timeout: const Duration(seconds: 3));

      // Step 3: Immediate one-shot query so the UI is up-to-date NOW.
      final latest = await _repo.getWorkOrdersByDate(state.currentDate!);
      state = state.copyWith(workOrders: latest, clearError: true);
    } catch (e) {
      debugPrint('[Manager] syncAfterMutation failed: $e');
    }
  }

  Future<void> loadWorkOrdersByDate(DateTime selectedDate,
      {bool fromDateOnwards = false}) async {
    state = state.copyWith(currentDate: selectedDate);

    await _repo.ensureInitialized();

    try {
      await _ordersSubscription?.cancel();

      final stream = fromDateOnwards
          ? _repo.watchWorkOrdersFromDate(selectedDate)
          : _repo.watchWorkOrdersByDate(selectedDate);

      _ordersSubscription = stream.listen(
        (orders) {
          state = state.copyWith(workOrders: orders, clearError: true);
        },
        onError: (error) {
          debugPrint('[Manager] Stream Error: $error');
          state = state.copyWith(errorMessage: 'Failed to load: $error');
        },
      );
    } catch (e) {
      debugPrint('[Manager] loadWorkOrdersByDate failed: $e');
      state = state.copyWith(errorMessage: 'Error: $e');
    }
  }

  Future<bool> assignTechnician(
      WorkOrder order, int techId, String techName, String managerName) async {
    final updatedOrder = order.copyWith(
      assignedId: techId,
      assignedTo: techName,
      status: 'assigned',
      lastUpdatedBy: managerName,
      lastUpdatedAt: DateTime.now(),
    );

    final formattedDate =
        "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')} ${DateTime.now().hour > 12 ? DateTime.now().hour - 12 : DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')} ${DateTime.now().hour >= 12 ? 'PM' : 'AM'}";

    final existingTimeline = List<String>.from(order.timeLine);
    existingTimeline
        .add("$formattedDate | $managerName | Assigned To $techName");

    final customDoc = updatedOrder.buildDoc();
    customDoc['time_line'] = existingTimeline;

    return await _repo.updateWorkOrder(updatedOrder, customDoc: customDoc);
  }

  Future<bool> cancelWorkOrder(
      WorkOrder order, String reason, String cancelledBy) async {
    final updatedOrder = order.copyWith(
      status: 'cancelled',
      lastUpdatedBy: cancelledBy,
      lastUpdatedAt: DateTime.now(),
    );

    final customDoc = updatedOrder.buildDoc();
    customDoc['cancel_reason'] = reason;

    return await _repo.updateWorkOrder(updatedOrder, customDoc: customDoc);
  }

  Future<bool> reassignTechnician(WorkOrder order, int newTechId,
      String newTechName, String managerName) async {
    final updatedOrder = order.copyWith(
      assignedId: newTechId,
      assignedTo: newTechName,
      status: 'assigned',
      lastUpdatedBy: managerName,
      lastUpdatedAt: DateTime.now(),
    );
    return await _repo.updateWorkOrder(updatedOrder);
  }

  Future<bool> softDeleteWorkOrder(String id, String user) async {
    return await _repo.softDeleteWorkOrder(id, user);
  }

  Future<bool> updateWorkOrder(WorkOrder order,
      {Map<String, dynamic>? customDoc}) async {
    return await _repo.updateWorkOrder(order, customDoc: customDoc);
  }

  Future<List<WorkOrder>> searchWorkOrdersAsync(String query) async {
    return await _repo.searchWorkOrdersAsync(state.workOrders, query);
  }

  List<WorkOrder> searchWorkOrders(String query) {
    return _repo.searchWorkOrders(state.workOrders, query);
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Main notifier — autoDispose so the stream is cleaned up on navigation away.
final managerWONotifierProvider =
    AutoDisposeNotifierProvider<ManagerWONotifier, ManagerWOState>(
        ManagerWONotifier.new);

/// Separate sync status stream — decoupled from work orders so AppBar
/// rebuilds independently without triggering full list rebuilds.
final managerSyncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final repo = ref.watch(managerWorkOrderRepositoryProvider);
  return repo.watchSyncStatus();
});

final managerTodayPod = StateProvider<DateTime>((_) {
  // if (Settings.development) {
  //   return DateTime(2022, 12, 14);
  // }
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

final managerSelectedDatePod =
    StateProvider<DateTime>((ref) => ref.watch(managerTodayPod));

final managerSearchPod = StateProvider<String>((_) => '');

/// Status filter for mobile view: 'all', 'new', 'in_progress', 'finished'
final managerStatusFilterPod = StateProvider<String>((_) => 'all');

final managerSortColumnPod = StateProvider<String>((_) => 'date');

final managerSortAscendingPod = StateProvider<bool>((_) => false);

final managerFilteredWorkOrdersPod = Provider<List<WorkOrder>>((ref) {
  final woState = ref.watch(
    managerWONotifierProvider.select((s) => s.workOrders),
  );
  final search = ref.watch(managerSearchPod);
  final sortCol = ref.watch(managerSortColumnPod);
  final sortAsc = ref.watch(managerSortAscendingPod);
  final statusFilter = ref.watch(managerStatusFilterPod);

  // 1. Search filter
  List<WorkOrder> filtered = search.isEmpty
      ? List.from(woState)
      : woState.where((wo) {
          final term = search.toLowerCase();
          return wo.searchableText.contains(term);
        }).toList();

  // 2. Status filter (used by mobile view chips)
  if (statusFilter != 'all') {
    filtered = filtered.where((wo) {
      final s = wo.status.toLowerCase().trim();
      switch (statusFilter) {
        case 'new':
          return s == 'assigned' || s.startsWith('un');
        case 'in_progress':
          return s.contains('step');
        case 'finished':
          return s == 'finished';
        case 'cancelled':
          return s == 'cancelled' || s == 'na';
        default:
          return true;
      }
    }).toList();
  }

  // 3. Sort
  filtered.sort((a, b) {
    int cmp = 0;
    switch (sortCol) {
      case 'name':
        cmp = a.patientName.toLowerCase().compareTo(b.patientName.toLowerCase());
        break;
      case 'status':
        cmp = a.status.compareTo(b.status);
        break;
      case 'server_status':
        cmp = a.serverStatus.compareTo(b.serverStatus);
        break;
      case 'assigned_to':
        // Empty (Unassigned) always last when ascending
        final aEmpty = a.assignedTo.isEmpty;
        final bEmpty = b.assignedTo.isEmpty;
        if (aEmpty && bEmpty) {
          cmp = 0;
        } else if (aEmpty) {
          cmp = 1;
        } else if (bEmpty) {
          cmp = -1;
        } else {
          cmp = a.assignedTo.toLowerCase().compareTo(b.assignedTo.toLowerCase());
        }
        break;
      case 'time':
        cmp = a.visitTime.compareTo(b.visitTime);
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
