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

  Future<void> loadWorkOrdersByDate(DateTime selectedDate) async {
    debugPrint('Manager loading orders for: $selectedDate');

    await _repo.ensureInitialized();

    try {
      await _ordersSubscription?.cancel();

      _ordersSubscription = _repo.watchWorkOrdersByDate(selectedDate).listen(
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
    return await _repo.updateWorkOrder(updatedOrder);
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
