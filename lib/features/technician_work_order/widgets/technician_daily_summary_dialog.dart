import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:anderson_crm_flutter/config/settings.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import '../../theme/theme.dart';
import '../providers/technician_work_order_provider.dart';

// final _selectedDateProvider = StateProvider<DateTime>(
//   (ref) {
//     final now = Settings.development ? DateTime(2022, 12, 14) : DateTime.now();
//     return DateTime(now.year, now.month, now.day);
//   },
// );

final _selectedDateProvider = StateProvider<DateTime>((ref) {
  return DateTime.now();
});

final _techDailySummaryProvider = FutureProvider.family<Map<String, dynamic>,
    ({String techId, String dateStr})>((ref, params) async {
  final provider = ref.read(technicianWONotifierProvider.notifier);

  final orders = await provider.getDailyOrders(params.techId, params.dateStr);

  int totalAssigned = 0;
  int totalFinished = 0;
  int totalCancelled = 0;
  int totalPending = 0;
  double totalAmount = 0;
  double amountCollected = 0;
  double amountAccepted = 0;
  List<String> times = [];

  for (final order in orders) {
    totalAssigned++;

    final status = order['status']?.toString() ?? '';
    if (status == 'Finished') {
      totalFinished++;
    } else if (status == 'cancelled') {
      totalCancelled++;
    } else {
      totalPending++;
    }

    final doc = jsonDecode(order['doc']?.toString() ?? '{}');

    final visitTime = order['visit_time']?.toString() ?? '';
    if (visitTime.isNotEmpty) {
      times.add(visitTime);
    }

    final amountReceived =
        double.tryParse(order['received_amount']?.toString() ?? '0') ?? 0;
    if (amountReceived > 0) {
      totalAmount += amountReceived;

      if (doc['remittance'] == true) {
        amountCollected += amountReceived;
      }

      if (doc['accept_remittance'] == true) {
        amountAccepted += amountReceived;
      }
    }
  }

  times.sort();
  final timeTill = times.isNotEmpty ? times.last : '';

  return {
    'total_assigned': totalAssigned,
    'total_finished': totalFinished,
    'total_cancelled': totalCancelled,
    'total_pending': totalPending,
    'total_amount': totalAmount,
    'amount_collected': amountCollected,
    'amount_accepted': amountAccepted,
    'time_till': timeTill,
    'orders': orders,
  };
});

class TechnicianDailySummaryDialog extends ConsumerWidget {
  const TechnicianDailySummaryDialog({super.key});

  List<DateTime> _getSuitableDates() {
    final now = Settings.development ? DateTime(2022, 12, 14) : DateTime.now();
    // Normalize to midnight (strip time) to ensure dropdown matching
    final baseDate = DateTime(now.year, now.month, now.day);
    return [
      baseDate.add(const Duration(days: 1)),
      baseDate,
      baseDate.subtract(const Duration(days: 1)),
      baseDate.subtract(const Duration(days: 2)),
      baseDate.subtract(const Duration(days: 3)),
      baseDate.subtract(const Duration(days: 4)),
      baseDate.subtract(const Duration(days: 5)),
    ];
  }

  String _formatDateForDisplay(DateTime date) {
    return DateFormat('EEE dd MMM yyyy').format(date);
  }

  String _formatDateForQuery(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(_selectedDateProvider);
    final storage = ref.read(storageServiceProvider);
    final techId = storage.getFromSession('logged_in_emp_id');

    final suitableDates = _getSuitableDates();

    final summaryAsync = ref.watch(_techDailySummaryProvider((
      techId: techId,
      dateStr: _formatDateForQuery(selectedDate),
    )));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'Technician Daily Summary',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 280,
                  child: DropdownButtonFormField<DateTime>(
                    value: selectedDate,
                    decoration: const InputDecoration(
                      labelText: 'Choose Collection Date',
                      border: OutlineInputBorder(),
                    ),
                    items: suitableDates.map((date) {
                      return DropdownMenuItem(
                        value: date,
                        child: Text(_formatDateForDisplay(date)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        ref.read(_selectedDateProvider.notifier).state = value;
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: summaryAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
              data: (summary) {
                final totalAssigned = summary['total_assigned'] ?? 0;

                if (totalAssigned == 0) {
                  return const Center(
                    child: Text(
                      'No work orders for this date',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  );
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildSummaryCard(summary),
                      const SizedBox(height: 16),
                      _buildAmountCard(summary),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> summary) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Work Order Summary',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.primary,
              ),
            ),
            const Divider(),
            const SizedBox(height: 8),
            _buildStatRow(
              'Assigned',
              '${summary['total_assigned'] ?? 0}',
              Colors.blue,
            ),
            _buildStatRow(
              'Cancelled',
              '${summary['total_cancelled'] ?? 0}',
              Colors.grey,
            ),
            _buildStatRow(
              'Finished',
              '${summary['total_finished'] ?? 0}',
              Colors.green,
            ),
            _buildStatRow(
              'Pending',
              '${summary['total_pending'] ?? 0}',
              Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountCard(Map<String, dynamic> summary) {
    final totalAmount = summary['total_amount'] ?? 0.0;
    final amountCollected = summary['amount_collected'] ?? 0.0;
    final amountAccepted = summary['amount_accepted'] ?? 0.0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Amount Details',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.blue,
              ),
            ),
            const Divider(),
            const SizedBox(height: 8),
            _buildAmountRow(
              'Collected',
              '₹${totalAmount.toStringAsFixed(0)}',
              Colors.blue,
            ),
            _buildAmountRow(
              'Handed Over',
              '₹${amountCollected.toStringAsFixed(0)}',
              Colors.green,
            ),
            _buildAmountRow(
              'Accepted',
              '₹${amountAccepted.toStringAsFixed(0)}',
              Colors.teal,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
