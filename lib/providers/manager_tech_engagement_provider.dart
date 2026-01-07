import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:anderson_crm_flutter/powersync/powersync_service.dart';
import 'package:anderson_crm_flutter/services/postgresService.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import 'package:anderson_crm_flutter/features/core/util.dart';
import 'package:anderson_crm_flutter/config/settings.dart';

// --- Data Models ---

class TechSummary {
  final String id;
  final String name;
  final int assigned;
  final int finished;
  final int cancelled;
  final int pending;
  final double totalAmount;
  final double amountCollected; // Accepted
  final double cash;
  final double gpay;
  final double hcCharges;
  final String timeTill;
  final List<Map<String, dynamic>> orders;

  TechSummary({
    required this.id,
    required this.name,
    this.assigned = 0,
    this.finished = 0,
    this.cancelled = 0,
    this.pending = 0,
    this.totalAmount = 0,
    this.amountCollected = 0,
    this.cash = 0,
    this.gpay = 0,
    this.hcCharges = 0,
    this.timeTill = '',
    this.orders = const [],
  });
}

class AggregateSummary {
  final int totalAssigned;
  final int totalFinished;
  final int totalCancelled;
  final int totalPending;
  final double totalCash;
  final double totalGpay;
  final double totalHcCharges;
  final double totalCollected;
  final double totalReceived;
  final int totalAccounted; // Excluding Glucose PP

  AggregateSummary({
    this.totalAssigned = 0,
    this.totalFinished = 0,
    this.totalCancelled = 0,
    this.totalPending = 0,
    this.totalCash = 0,
    this.totalGpay = 0,
    this.totalHcCharges = 0,
    this.totalCollected = 0,
    this.totalReceived = 0,
    this.totalAccounted = 0,
  });
}

class ManagerTechEngagementState {
  final bool isLoading;
  final bool isMonthWise; // ✅ Toggle State
  final DateTime selectedDate;
  final AggregateSummary aggregates;
  final List<TechSummary> techList; // Full List
  final List<TechSummary> filteredList; // Search Results

  ManagerTechEngagementState({
    this.isLoading = false,
    this.isMonthWise = false,
    required this.selectedDate,
    required this.aggregates,
    this.techList = const [],
    this.filteredList = const [],
  });

  ManagerTechEngagementState copyWith({
    bool? isLoading,
    bool? isMonthWise,
    DateTime? selectedDate,
    AggregateSummary? aggregates,
    List<TechSummary>? techList,
    List<TechSummary>? filteredList,
  }) {
    return ManagerTechEngagementState(
      isLoading: isLoading ?? this.isLoading,
      isMonthWise: isMonthWise ?? this.isMonthWise,
      selectedDate: selectedDate ?? this.selectedDate,
      aggregates: aggregates ?? this.aggregates,
      techList: techList ?? this.techList,
      filteredList: filteredList ?? this.filteredList,
    );
  }
}

// --- Notifier Logic ---

class ManagerTechEngagementNotifier
    extends StateNotifier<ManagerTechEngagementState> {
  final Ref ref;

  ManagerTechEngagementNotifier(this.ref)
      : super(ManagerTechEngagementState(
          selectedDate:
              Settings.development ? DateTime(2022, 12, 14) : DateTime.now(),
          aggregates: AggregateSummary(),
        ));

  Future<void> loadData() async {
    state = state.copyWith(isLoading: true);

    try {
      final postgres = ref.read(postgresServiceProvider);
      final powerSync = ref.read(powerSyncServiceProvider);

      List<Map<String, dynamic>> allOrders = [];

      // 1. Determine Date Range
      if (state.isMonthWise) {
        // First to Last day of selected month
        final start =
            DateTime(state.selectedDate.year, state.selectedDate.month, 1);
        final end =
            DateTime(state.selectedDate.year, state.selectedDate.month + 1, 0);

        final startStr = DateFormat('yyyy-MM-dd').format(start);
        final endStr = DateFormat('yyyy-MM-dd').format(end);

        // Fetch Parallel
        final results = await Future.wait([
          postgres.getTechnicians(),
          powerSync.getAllWorkOrdersForDateRange(startStr, endStr)
        ]);
        allOrders = results[1] as List<Map<String, dynamic>>;
        // Technicians processing below...
        _processData(results[0] as List, allOrders);
      } else {
        // Single Date
        final dateStr = DateFormat('yyyy-MM-dd').format(state.selectedDate);
        final results = await Future.wait([
          postgres.getTechnicians(),
          powerSync.getAllWorkOrdersForDate(dateStr)
        ]);
        allOrders = results[1] as List<Map<String, dynamic>>;
        _processData(results[0] as List, allOrders);
      }
    } catch (e) {
      debugPrint("Error loading stats: $e");
      state = state.copyWith(isLoading: false);
    }
  }

  void _processData(
      List<dynamic> rawTechs, List<Map<String, dynamic>> allOrders) {
    List<Map<String, dynamic>> technicians = [];
    if (rawTechs.isNotEmpty) {
      technicians = List<Map<String, dynamic>>.from(rawTechs);
    }

    List<TechSummary> summaries = [];

    // Aggregates
    int gAssigned = 0, gFinished = 0, gCancelled = 0, gPending = 0;
    double gCash = 0, gGpay = 0, gHc = 0, gTotalColl = 0, gTotalRec = 0;
    int gTotalAccounted = 0;

    for (var tech in technicians) {
      final techId =
          tech['emp_id']?.toString() ?? tech['_id']?.toString() ?? '';
      final techName =
          tech['name'] ?? '${tech['first_name']} ${tech['last_name']}';

      int assigned = 0, finished = 0, cancelled = 0, pending = 0;
      double total = 0, collected = 0, cash = 0, gpay = 0, hc = 0;
      List<Map<String, dynamic>> myOrders = [];
      List<String> times = [];

      for (var order in allOrders) {
        if (order['assigned_id'].toString() == techId) {
          assigned++;
          myOrders.add(order);

          final status = order['status']?.toString() ?? '';
          if (status == 'Finished') {
            finished++;
            // Check Glucose PP Logic (Simplified check)
            if (!_isGlucosePPOnly(order)) {
              gTotalAccounted++;
            }
          } else if (status == 'cancelled')
            cancelled++;
          else
            pending++;

          times.add(order['visit_time'] ?? '');

          final doc = jsonDecode(order['doc'] ?? '{}');
          final amountReceived =
              double.tryParse(order['received_amount']?.toString() ?? '0') ?? 0;
          final hcCharge =
              double.tryParse(doc['hc_charges']?.toString() ?? '0') ?? 0;
          final paymentMethod = doc['payment_method']?.toString() ?? '';

          if (amountReceived > 0) {
            total += amountReceived;
            if (doc['accept_remittance'] == true) collected += amountReceived;
            if (paymentMethod == 'cash') cash += amountReceived;
            if (paymentMethod == 'gpay') gpay += amountReceived;
            hc += hcCharge;
          }
        }
      }

      gAssigned += assigned;
      gFinished += finished;
      gCancelled += cancelled;
      gPending += pending;
      gCash += cash;
      gGpay += gpay;
      gHc += hc;
      gTotalColl += total;
      gTotalRec += collected;

      times.sort();
      final timeTill = times.isNotEmpty ? times.last : '';

      // Only add if active or short list
      if (assigned > 0 || technicians.length < 50) {
        summaries.add(TechSummary(
          id: techId,
          name: techName,
          assigned: assigned,
          finished: finished,
          cancelled: cancelled,
          pending: pending,
          totalAmount: total,
          amountCollected: collected,
          cash: cash,
          gpay: gpay,
          hcCharges: hc,
          timeTill: timeTill,
          orders: myOrders,
        ));
      }
    }

    state = state.copyWith(
        isLoading: false,
        techList: summaries,
        filteredList: summaries, // Init filtered with full
        aggregates: AggregateSummary(
            totalAssigned: gAssigned,
            totalFinished: gFinished,
            totalCancelled: gCancelled,
            totalPending: gPending,
            totalCash: gCash,
            totalGpay: gGpay,
            totalHcCharges: gHc,
            totalCollected: gTotalColl,
            totalReceived: gTotalRec,
            totalAccounted: gTotalAccounted));
  }

  // Helper to guess Glucose PP Only (matches Vue logic intent)
  bool _isGlucosePPOnly(Map<String, dynamic> order) {
    // This logic mimics standard lab checks.
    // In Vue it calls WorkOrderDB.glucose_pp_only(item).
    // We check if "Glucose (PP)" is the ONLY test.
    try {
      final doc = jsonDecode(order['doc'] ?? '{}');
      if (doc['test_items'] != null) {
        List items = doc['test_items'];
        if (items.length == 1) {
          String name = items[0]['invest_name'].toString().toLowerCase();
          if (name.contains('glucose') &&
              (name.contains('pp') || name.contains('post prandial'))) {
            return true;
          }
        }
      }
    } catch (e) {}
    return false;
  }

  void search(String query) {
    if (query.isEmpty) {
      state = state.copyWith(filteredList: state.techList);
    } else {
      final lower = query.toLowerCase();
      final filtered = state.techList
          .where((tech) => tech.name.toLowerCase().contains(lower))
          .toList();
      state = state.copyWith(filteredList: filtered);
    }
  }

  void setDate(DateTime date) {
    state = state.copyWith(selectedDate: date);
    loadData();
  }

  void toggleMonthWise(bool value) {
    state = state.copyWith(isMonthWise: value);
    loadData();
  }

  Future<void> toggleRemittance(String workOrderId, bool currentValue) async {
    try {
      final db = ref.read(powerSyncServiceProvider);
      final storage = ref.read(storageServiceProvider);
      final user = storage.getFromSession('logged_in_emp_name') ?? 'Manager';
      await db.toggleRemittanceAcceptance(workOrderId, !currentValue, user);
      await loadData();
    } catch (e) {
      debugPrint("Error toggling remittance: $e");
    }
  }
}

final managerTechEngagementProvider = StateNotifierProvider<
    ManagerTechEngagementNotifier, ManagerTechEngagementState>((ref) {
  return ManagerTechEngagementNotifier(ref);
});
