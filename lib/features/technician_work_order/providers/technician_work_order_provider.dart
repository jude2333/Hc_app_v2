import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:powersync/powersync.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/repositories/temp_upload_repository.dart';
import '../repositories/technician_work_order_repository.dart';

@immutable
class TechnicianWOState {
  final List<WorkOrder> workOrders;
  final bool isLoading;
  final bool isInitializing;
  final String? errorMessage;

  const TechnicianWOState({
    this.workOrders = const [],
    this.isLoading = false,
    this.isInitializing = true,
    this.errorMessage,
  });

  TechnicianWOState copyWith({
    List<WorkOrder>? workOrders,
    bool? isLoading,
    bool? isInitializing,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TechnicianWOState(
      workOrders: workOrders ?? this.workOrders,
      isLoading: isLoading ?? this.isLoading,
      isInitializing: isInitializing ?? this.isInitializing,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class TechnicianWONotifier extends AutoDisposeNotifier<TechnicianWOState> {
  late final TechnicianWorkOrderRepository _repo;
  StreamSubscription<List<WorkOrder>>? _ordersSubscription;

  @override
  TechnicianWOState build() {
    _repo = ref.watch(technicianWorkOrderRepositoryProvider);
    debugPrint('TechnicianWONotifier build() called');

    ref.onDispose(() {
      debugPrint('TechnicianWONotifier DISPOSED - Closing stream!');
      _ordersSubscription?.cancel();
    });

    return const TechnicianWOState();
  }

  Future<void> initialize() async {
    state = state.copyWith(isLoading: true);
    await _repo.initialize();
    try {
      final tempRepo = ref.read(tempUploadRepositoryProvider);
      final cleaned = await tempRepo.cleanupOldUploads();
      if (cleaned > 0) {
        debugPrint('[Tech] Cleaned $cleaned old temp uploads from local DB');
      }
    } catch (e) {
      debugPrint('[Tech] Temp upload cleanup failed (non-fatal): $e');
    }

    state = state.copyWith(isLoading: false, isInitializing: false);
  }

  Future<void> loadTechnicianWorkOrders(String techId) async {
    await _repo.ensureInitialized();

    try {
      await _ordersSubscription?.cancel();

      _ordersSubscription = _repo.watchTechnicianWorkOrders(techId).listen(
        (orders) {
          final filtered = orders
              .where((wo) => wo.status.toLowerCase() != 'unassigned')
              .toList();
          state = state.copyWith(workOrders: filtered, clearError: true);
        },
        onError: (error) {
          debugPrint('[Tech] Stream Error: $error');
          state = state.copyWith(errorMessage: 'Failed to load: $error');
        },
      );
    } catch (e) {
      debugPrint('[Tech] loadTechnicianWorkOrders failed: $e');
      state = state.copyWith(errorMessage: 'Error: $e');
    }
  }

  Future<void> _syncAfterMutation() async {
    try {
      await _repo.waitForSync(timeout: const Duration(seconds: 10));
      await _repo.waitForCheckpointOrReconnect(
          timeout: const Duration(seconds: 3));
    } catch (e) {
      debugPrint('[Tech] syncAfterMutation failed: $e');
    }
  }

  Future<bool> updateStatus(
      WorkOrder order, String status, String updatedBy) async {
    final updatedOrder = order.copyWith(
      status: status,
      lastUpdatedBy: updatedBy,
      lastUpdatedAt: DateTime.now(),
    );
    final result = await _repo.updateWorkOrder(updatedOrder);
    if (result) await _syncAfterMutation();
    return result;
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

    final result =
        await _repo.updateWorkOrder(updatedOrder, customDoc: customDoc);
    if (result) await _syncAfterMutation();
    return result;
  }

  Future<bool> updateWorkOrder(WorkOrder order,
      {Map<String, dynamic>? customDoc}) async {
    final result = await _repo.updateWorkOrder(order, customDoc: customDoc);
    if (result) await _syncAfterMutation();
    return result;
  }

  Future<bool> createWorkOrder(WorkOrder order) async {
    final result = await _repo.createWorkOrder(order);
    if (result) await _syncAfterMutation();
    return result;
  }

  Future<List<WorkOrder>> searchWorkOrdersAsync(String query) async {
    return await _repo.searchWorkOrdersAsync(state.workOrders, query);
  }

  List<WorkOrder> searchWorkOrders(String query) {
    return _repo.searchWorkOrders(state.workOrders, query);
  }

  Future<bool> updateRemittance(
      WorkOrder order, bool remittance, String user) async {
    final timeline = List<dynamic>.from(order.timeLine);
    final timestamp = DateTime.now().toString().substring(0, 16);
    final logEntry = remittance
        ? '$timestamp - $user - Remittance Made.'
        : '$timestamp - $user - Remittance Cancelled.';
    timeline.add(logEntry);

    final customDoc = order.buildDoc();
    customDoc['remittance'] = remittance;
    customDoc['accept_remittance'] = false;
    customDoc['time_line'] = timeline;

    final updatedOrder = order.copyWith(
      lastUpdatedBy: user,
      lastUpdatedAt: DateTime.now(),
    );

    final result =
        await _repo.updateWorkOrder(updatedOrder, customDoc: customDoc);
    if (result) await _syncAfterMutation();
    return result;
  }

  Future<bool> updateGPayRef(
      WorkOrder order, String gpayRef, String user) async {
    final timeline = List<dynamic>.from(order.timeLine);
    final timestamp = DateTime.now().toString().substring(0, 16);
    timeline.add('$timestamp - $user - GPay Ref Updated: $gpayRef');

    final customDoc = order.buildDoc();
    customDoc['gpay_ref'] = gpayRef;
    customDoc['time_line'] = timeline;

    final updatedOrder = order.copyWith(
      lastUpdatedBy: user,
      lastUpdatedAt: DateTime.now(),
    );

    final result =
        await _repo.updateWorkOrder(updatedOrder, customDoc: customDoc);
    if (result) await _syncAfterMutation();
    return result;
  }

  Future<bool> updateRemarks(
      WorkOrder order, String remarks, String user) async {
    final timeline = List<dynamic>.from(order.timeLine);
    final timestamp = DateTime.now().toString().substring(0, 16);
    timeline.add('$timestamp - $user - Remarks Updated');

    final customDoc = order.buildDoc();
    customDoc['remarks'] = remarks;
    customDoc['time_line'] = timeline;

    final updatedOrder = order.copyWith(
      lastUpdatedBy: user,
      lastUpdatedAt: DateTime.now(),
    );

    final result =
        await _repo.updateWorkOrder(updatedOrder, customDoc: customDoc);
    if (result) await _syncAfterMutation();
    return result;
  }

  Future<bool> addLabSamplePhoto(
      WorkOrder order, String photoPath, String user) async {
    final timeline = List<dynamic>.from(order.timeLine);
    final timestamp = DateTime.now().toString().substring(0, 16);
    timeline.add('$timestamp - $user - Lab Sample Pic Uploaded');

    final existingPics = order.parsedDoc['lab_sample_pics']?.toString() ?? '';
    final newPics =
        existingPics.isEmpty ? photoPath : '$existingPics,$photoPath';

    final customDoc = order.buildDoc();
    customDoc['lab_sample_pics'] = newPics;
    customDoc['time_line'] = timeline;

    final updatedOrder = order.copyWith(
      lastUpdatedBy: user,
      lastUpdatedAt: DateTime.now(),
    );

    final result =
        await _repo.updateWorkOrder(updatedOrder, customDoc: customDoc);
    if (result) await _syncAfterMutation();
    return result;
  }

  Future<List<Map<String, dynamic>>> getDailyOrders(
      String techId, String dateStr) async {
    await _repo.ensureInitialized();
    return await _repo.getDailyOrders(techId, dateStr);
  }

  WorkOrder? getWorkOrderById(String docId) {
    try {
      return state.workOrders.firstWhere((wo) => wo.docId == docId);
    } catch (e) {
      return null;
    }
  }
}

final technicianWONotifierProvider =
    AutoDisposeNotifierProvider<TechnicianWONotifier, TechnicianWOState>(
        TechnicianWONotifier.new);
final techSyncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final repo = ref.watch(technicianWorkOrderRepositoryProvider);
  return repo.watchSyncStatus();
});
final techSearchPod = AutoDisposeStateProvider<String>((_) => '');
final techSortColumnPod = AutoDisposeStateProvider<String>((_) => 'priority');
final techSortAscendingPod = AutoDisposeStateProvider<bool>((_) => true);
final techStatusFilterPod = AutoDisposeStateProvider<String>((_) => 'all');
int _statusPriority(String status) {
  final s = status.toLowerCase().trim();
  if (s == 'assigned' || s.startsWith('un')) return 0;
  if (s.contains('step')) return 1;
  if (s == 'finished') return 2;
  if (s == 'cancelled' || s == 'na' || s.isEmpty) return 3;
  return 1; // fallback: treat unknown as in-progress
}

String statusGroupLabel(String status) {
  switch (_statusPriority(status)) {
    case 0:
      return 'New';
    case 1:
      return 'In Progress';
    case 2:
      return 'Finished';
    case 3:
      return 'Cancelled';
    default:
      return 'Other';
  }
}

final techFilteredWorkOrdersPod = AutoDisposeProvider<List<WorkOrder>>((ref) {
  final woState = ref.watch(
    technicianWONotifierProvider.select((s) => s.workOrders),
  );
  final search = ref.watch(techSearchPod);
  final sortCol = ref.watch(techSortColumnPod);
  final sortAsc = ref.watch(techSortAscendingPod);
  final statusFilter = ref.watch(techStatusFilterPod);
  List<WorkOrder> filtered = search.isEmpty
      ? List.from(woState)
      : woState.where((wo) {
          final term = search.toLowerCase();
          return wo.searchableText.contains(term);
        }).toList();
  if (statusFilter != 'all') {
    filtered = filtered.where((wo) {
      final priority = _statusPriority(wo.status);
      switch (statusFilter) {
        case 'new':
          return priority == 0;
        case 'in_progress':
          return priority == 1;
        case 'finished':
          return priority == 2;
        default:
          return true;
      }
    }).toList();
  }
  filtered.sort((a, b) {
    int cmp = 0;
    switch (sortCol) {
      case 'name':
        cmp = a.patientName.compareTo(b.patientName);
        break;
      case 'status':
        cmp = _statusPriority(a.status).compareTo(_statusPriority(b.status));
        if (cmp == 0) {
          cmp = b.visitDate.compareTo(a.visitDate);
          if (cmp == 0) cmp = b.visitTime.compareTo(a.visitTime);
        }
        break;
      case 'date':
        cmp = a.visitDate.compareTo(b.visitDate);
        if (cmp == 0) cmp = a.visitTime.compareTo(b.visitTime);
        break;
      case 'priority':
      default:
        cmp = _statusPriority(a.status).compareTo(_statusPriority(b.status));
        if (cmp == 0) {
          cmp = b.visitDate.compareTo(a.visitDate);
          if (cmp == 0) cmp = b.visitTime.compareTo(a.visitTime);
        }
        break;
    }
    return sortAsc ? cmp : -cmp;
  });

  return filtered;
});
