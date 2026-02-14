import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/config/settings.dart';
import '../repositories/manager_work_order_repository.dart';

class ManagerWorkOrderProvider extends ChangeNotifier {
  final ManagerWorkOrderRepository _repo;

  ManagerWorkOrderProvider({required ManagerWorkOrderRepository repository})
      : _repo = repository {
    debugPrint('ManagerWorkOrderProvider CONSTRUCTOR called');
  }

  List<WorkOrder> _workOrders = [];
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _currentDate;
  StreamSubscription<List<WorkOrder>>? _ordersSubscription;

  List<WorkOrder> get workOrders => _workOrders;
  bool get isInitializing => _repo.isInitializing;
  bool get isLoading => _isLoading;
  bool get isConnected => _repo.isConnected;
  bool get isSyncing => _repo.isSyncing;
  bool get hasPendingUploads => _repo.hasPendingUploads;
  String? get errorMessage => _errorMessage;
  DateTime? get currentDate => _currentDate;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    await _repo.initialize();
    _isLoading = false;
    notifyListeners();
  }

  /// After a local mutation, wait for the CRUD queue to drain,
  /// then do an immediate one-shot query so the UI is up-to-date.
  /// The recoverable watch streams in PowerSyncService will handle
  /// catching any subsequent updates automatically.
  Future<void> syncAfterMutation() async {
    if (_currentDate == null) return;
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
      final latest = await _repo.getWorkOrdersByDate(_currentDate!);
      _workOrders = latest;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      debugPrint('[Manager] syncAfterMutation failed: $e');
    }
  }

  Future<void> loadWorkOrdersByDate(DateTime selectedDate,
      {bool fromDateOnwards = false}) async {
    _currentDate = selectedDate;

    await _repo.ensureInitialized();

    try {
      await _ordersSubscription?.cancel();

      final stream = fromDateOnwards
          ? _repo.watchWorkOrdersFromDate(selectedDate)
          : _repo.watchWorkOrdersByDate(selectedDate);

      _ordersSubscription = stream.listen(
        (orders) {
          _workOrders = orders;
          _errorMessage = null;
          notifyListeners();
        },
        onError: (error) {
          debugPrint('[Manager] Stream Error: $error');
          _errorMessage = 'Failed to load: $error';
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('[Manager] loadWorkOrdersByDate failed: $e');
      _errorMessage = 'Error: $e';
      notifyListeners();
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

  Future<bool> softDeleteWorkOrder(int id, String user) async {
    return await _repo.softDeleteWorkOrder(id, user);
  }

  Future<bool> updateWorkOrder(WorkOrder order,
      {Map<String, dynamic>? customDoc}) async {
    return await _repo.updateWorkOrder(order, customDoc: customDoc);
  }

  Future<List<WorkOrder>> searchWorkOrdersAsync(String query) async {
    return await _repo.searchWorkOrdersAsync(_workOrders, query);
  }

  List<WorkOrder> searchWorkOrders(String query) {
    return _repo.searchWorkOrders(_workOrders, query);
  }

  @override
  void dispose() {
    debugPrint('ManagerWorkOrderProvider DISPOSED - Closing stream!');
    _ordersSubscription?.cancel();
    super.dispose();
  }
}

final managerWorkOrderProvider =
    ChangeNotifierProvider<ManagerWorkOrderProvider>((ref) {
  final repo = ref.read(managerWorkOrderRepositoryProvider);
  return ManagerWorkOrderProvider(repository: repo);
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

final managerSortColumnPod = StateProvider<String>((_) => 'date');

final managerSortAscendingPod = StateProvider<bool>((_) => false);

final managerFilteredWorkOrdersPod = Provider<List<WorkOrder>>((ref) {
  final provider = ref.watch(managerWorkOrderProvider);
  final search = ref.watch(managerSearchPod);
  final sortCol = ref.watch(managerSortColumnPod);
  final sortAsc = ref.watch(managerSortAscendingPod);

  List<WorkOrder> filtered = search.isEmpty
      ? List.from(provider.workOrders)
      : provider.workOrders.where((wo) {
          final term = search.toLowerCase();
          return wo.searchableText.contains(term);
        }).toList();

  filtered.sort((a, b) {
    int cmp = 0;
    switch (sortCol) {
      case 'name':
        cmp = a.patientName.compareTo(b.patientName);
        break;
      case 'status':
        cmp = a.status.compareTo(b.status);
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
