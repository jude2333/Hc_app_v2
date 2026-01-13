import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
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
  StreamSubscription<List<WorkOrder>>? _ordersSubscription;

  List<WorkOrder> get workOrders => _workOrders;
  bool get isInitializing => _repo.isInitializing;
  bool get isLoading => _isLoading;
  bool get isConnected => _repo.isConnected;
  bool get isSyncing => _repo.isSyncing;
  bool get hasPendingUploads => _repo.hasPendingUploads;
  String? get errorMessage => _errorMessage;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    await _repo.initialize();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadWorkOrdersByDate(DateTime selectedDate,
      {bool fromDateOnwards = false}) async {
    debugPrint(
        'Manager loading orders for: $selectedDate (fromDateOnwards: $fromDateOnwards)');

    await _repo.ensureInitialized();

    try {
      await _ordersSubscription?.cancel();

      final stream = fromDateOnwards
          ? _repo.watchWorkOrdersFromDate(selectedDate)
          : _repo.watchWorkOrdersByDate(selectedDate);

      _ordersSubscription = stream.listen(
        (orders) {
          debugPrint('Manager UI notified with ${orders.length} work orders');
          _workOrders = orders;
          _errorMessage = null;
          notifyListeners();
        },
        onError: (error) {
          debugPrint(' Manager Stream Error: $error');
          _errorMessage = 'Failed to load: $error';
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint(' loadWorkOrdersByDate failed: $e');
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
    _ordersSubscription?.cancel();
    super.dispose();
  }
}

final managerWorkOrderProvider =
    ChangeNotifierProvider<ManagerWorkOrderProvider>((ref) {
  final repo = ref.read(managerWorkOrderRepositoryProvider);
  return ManagerWorkOrderProvider(repository: repo);
});

/// Today's date for reference (used for date chip calculations)
final managerTodayPod = StateProvider<DateTime>((_) => DateTime(2022, 12, 14));

/// Currently selected date for filtering work orders
final managerSelectedDatePod =
    StateProvider<DateTime>((ref) => ref.watch(managerTodayPod));

/// Search query for filtering work orders
final managerSearchPod = StateProvider<String>((_) => '');

/// Sort column for work order list
final managerSortColumnPod = StateProvider<String>((_) => 'date');

/// Sort direction for work order list
final managerSortAscendingPod = StateProvider<bool>((_) => false);

/// Filtered and sorted work orders - computed from raw work orders
/// This memoizes the filtering/sorting logic so it doesn't run on every build
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
