import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:anderson_crm_flutter/powersync/powersync_service.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';

class TechEngagementState {
  final bool isLoading;
  final Map<String, dynamic>? stats;
  final List<Map<String, dynamic>> orders;

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

      final orders = await db.getTechnicianDailyOrders(techId, dateStr);

      int assigned = 0, finished = 0, cancelled = 0, pending = 0;
      double totalAmount = 0, collected = 0, accepted = 0;

      for (var row in orders) {
        final status = row['status']?.toString() ?? '';
        assigned++;

        if (status == 'Finished')
          finished++;
        else if (status == 'cancelled')
          cancelled++;
        else
          pending++;

        final double received =
            double.tryParse(row['received_amount']?.toString() ?? '0') ?? 0;

        if (received > 0) {
          totalAmount += received;

          final doc = jsonDecode(row['doc'] ?? '{}');

          if (doc['amount_deposit'] != null &&
              doc['amount_deposit'].toString().isNotEmpty) {
            collected += received;
          }

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
