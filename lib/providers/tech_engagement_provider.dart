import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
// import 'package:anderson_crm_flutter/services/storage_service.dart';
import 'package:anderson_crm_flutter/powersync/powersync_service.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';

// The State Object
class TechEngagementState {
  final bool isLoading;
  final Map<String, dynamic>? stats; // {total_assigned, total_amount, etc}
  final List<Map<String, dynamic>>
      orders; // The raw orders (needed for remittance)

  TechEngagementState(
      {this.isLoading = false, this.stats, this.orders = const []});
}

class TechEngagementNotifier extends StateNotifier<TechEngagementState> {
  final Ref ref;

  TechEngagementNotifier(this.ref) : super(TechEngagementState());

  Future<void> loadData(DateTime date) async {
    state = TechEngagementState(isLoading: true);

    try {
      final storage = ref.read(storageServiceProvider);
      final db = ref.read(powerSyncServiceProvider);

      final techId =
          storage.getFromSession('logged_in_emp_id')?.toString() ?? '';
      final dateStr = DateFormat('yyyy-MM-dd').format(date);

      // 1. Fetch Raw Data
      final orders = await db.getTechnicianDailyOrders(techId, dateStr);

      // 2. Calculate Aggregates (Replicating Vue 'tech_Aggregate_view' logic)
      int assigned = 0, finished = 0, cancelled = 0, pending = 0;
      double totalAmount = 0, collected = 0, accepted = 0;

      for (var row in orders) {
        // Note: In Postgres, we might need to parse the JSON doc for some fields
        // if they aren't top-level columns. Assuming 'status' is a column.

        final status = row['status']?.toString() ?? '';
        assigned++;

        if (status == 'Finished')
          finished++;
        else if (status == 'cancelled')
          cancelled++;
        else
          pending++;

        // Financials (Check 'doc' for remittance details)
        // In your Vue code, 'amount_received' seems to be used for summing
        final double received =
            double.tryParse(row['received_amount']?.toString() ?? '0') ?? 0;

        if (received > 0) {
          totalAmount += received;

          // Parse doc to check remittance flags
          final doc = jsonDecode(row['doc'] ?? '{}');

          // If 'amount_deposit' exists, it counts as collected/handed over
          if (doc['amount_deposit'] != null &&
              doc['amount_deposit'].toString().isNotEmpty) {
            collected += received;
          }

          // If 'amount_deposited_status' is true (or accepted flag), counts as accepted
          if (doc['amount_deposited_status'] == true) {
            accepted += received;
          }
        }
      }

      final stats = {
        "total_assigned": assigned,
        "total_finished": finished,
        "total_cancelled": cancelled,
        "total_pending": pending,
        "total_amount": totalAmount,
        "amount_collected": collected,
        "amount_accepted": accepted,
      };

      state =
          TechEngagementState(isLoading: false, stats: stats, orders: orders);
    } catch (e) {
      state = TechEngagementState(isLoading: false);
      rethrow;
    }
  }

  Future<void> submitRemittance(String amount) async {
    if (state.orders.isEmpty) return;

    try {
      state = TechEngagementState(
          isLoading: true, stats: state.stats, orders: state.orders);

      final storage = ref.read(storageServiceProvider);
      final db = ref.read(powerSyncServiceProvider);
      final user = storage.getFromSession('logged_in_emp_name') ?? 'Technician';

      await db.submitRemittance(state.orders, amount, user);

      // Reload to refresh stats
      // (We assume the date hasn't changed, ideally pass date back or store it)
    } catch (e) {
      state = TechEngagementState(
          isLoading: false, stats: state.stats, orders: state.orders);
      rethrow;
    }
  }
}

final techEngagementProvider = StateNotifierProvider.autoDispose<
    TechEngagementNotifier, TechEngagementState>((ref) {
  return TechEngagementNotifier(ref);
});
