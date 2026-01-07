import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import '../repositories/technician_work_order_repository.dart';

class TechnicianWorkOrderProvider extends ChangeNotifier {
  final TechnicianWorkOrderRepository _repo;

  TechnicianWorkOrderProvider(
      {required TechnicianWorkOrderRepository repository})
      : _repo = repository {
    debugPrint('🏭 TechnicianWorkOrderProvider CONSTRUCTOR called');
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

  Future<void> loadTechnicianWorkOrders(String techId) async {
    debugPrint('👨‍🔧 Technician loading orders for: $techId');

    await _repo.ensureInitialized();

    try {
      await _ordersSubscription?.cancel();

      _ordersSubscription = _repo.watchTechnicianWorkOrders(techId).listen(
        (orders) {
          debugPrint(
              '✅ Technician UI notified with ${orders.length} work orders');
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

  Future<bool> updateStatus(
      WorkOrder order, String status, String updatedBy) async {
    final updatedOrder = order.copyWith(
      status: status,
      lastUpdatedBy: updatedBy,
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

  Future<bool> updateWorkOrder(WorkOrder order,
      {Map<String, dynamic>? customDoc}) async {
    return await _repo.updateWorkOrder(order, customDoc: customDoc);
  }

  Future<bool> createWorkOrder(WorkOrder order) async {
    return await _repo.createWorkOrder(order);
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

final technicianWorkOrderProvider =
    ChangeNotifierProvider<TechnicianWorkOrderProvider>((ref) {
  final repo = ref.read(technicianWorkOrderRepositoryProvider);
  return TechnicianWorkOrderProvider(repository: repo);
});
