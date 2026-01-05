import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import 'package:anderson_crm_flutter/powersync/powersync_service.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/util.dart';
import 'package:anderson_crm_flutter/config/settings.dart';

class TechEngagementPage extends ConsumerStatefulWidget {
  const TechEngagementPage({Key? key}) : super(key: key);

  @override
  ConsumerState<TechEngagementPage> createState() => _TechEngagementPageState();
}

class _TechEngagementPageState extends ConsumerState<TechEngagementPage> {
  final _amountController = TextEditingController();
  bool _isLoading = false;

  DateTime _selectedDate = DateTime.now();
  List<DateTime> _suitableDates = [];

  // Store raw WorkOrder objects to access 'receivedAmount' and 'parsedDoc' easily
  List<WorkOrder> _dailyOrders = [];

  // Stats
  int _totalAssigned = 0;
  int _totalFinished = 0;
  int _totalCancelled = 0;
  int _totalPending = 0;

  double _totalCollected = 0;
  double _amountHandedOver = 0;
  double _amountAccepted = 0;

  @override
  void initState() {
    super.initState();
    _generateDates();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
    });
  }

  void _generateDates() {
    final DateTime today =
        Settings.development ? DateTime(2022, 12, 14) : DateTime.now();

    _suitableDates =
        List.generate(7, (i) => today.subtract(Duration(days: i - 1)));
    _suitableDates
        .sort((a, b) => b.compareTo(a)); // Descending (Future -> Past)
    _selectedDate = today;
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final storage = ref.read(storageServiceProvider);
      final techId =
          storage.getFromSession('logged_in_emp_id')?.toString() ?? '';
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      // 1. Get Data from Postgres
      final rawRows = await ref
          .read(powerSyncServiceProvider)
          .getTechnicianDailyOrders(techId, dateStr);
      final orders = rawRows.map((r) => WorkOrder.fromRow(r)).toList();

      // 2. Calculate Stats (Vue Logic)
      _calculateStats(orders);

      setState(() {
        _dailyOrders = orders;
      });
    } catch (e) {
      debugPrint('Error loading tech engagement: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _calculateStats(List<WorkOrder> orders) {
    int assigned = 0, finished = 0, cancelled = 0, pending = 0;
    double collected = 0, handedOver = 0, accepted = 0;

    for (var order in orders) {
      assigned++;

      final status = order.status.toLowerCase();
      if (status == 'finished')
        finished++;
      else if (status == 'cancelled')
        cancelled++;
      else
        pending++;

      final double received = order.receivedAmount;

      if (received > 0) {
        collected += received;

        // Check JSON doc for tags
        final doc = order.parsedDoc;

        // Vue 'remittance' check: Is 'amount_deposit' present?
        if (doc['amount_deposit'] != null &&
            doc['amount_deposit'].toString().isNotEmpty &&
            doc['amount_deposit'].toString() != '0') {
          handedOver += received; // Sum the actual money, not the tag value
        }

        // Vue 'accept_remittance' check
        if (doc['amount_deposited_status'] == true ||
            doc['amount_deposited_status'] == 1) {
          accepted += received;
        }
      }
    }

    _totalAssigned = assigned;
    _totalFinished = finished;
    _totalCancelled = cancelled;
    _totalPending = pending;
    _totalCollected = collected;
    _amountHandedOver = handedOver;
    _amountAccepted = accepted;
  }

  Future<void> _submitRemittance() async {
    final amountStr = _amountController.text.trim();
    if (amountStr.isEmpty) return;

    final amount = double.tryParse(amountStr) ?? 0;
    if (amount <= 0) {
      _showSnackBar('Amount must be greater than 0', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final storage = ref.read(storageServiceProvider);
      final user = storage.getFromSession('logged_in_emp_name') ?? 'Technician';

      // Convert objects back to raw maps for the service
      final rawOrders = _dailyOrders.map((o) => o.toMap()).toList();

      await ref
          .read(powerSyncServiceProvider)
          .submitRemittance(rawOrders, amountStr, user);

      if (mounted) {
        _showSnackBar('Remitted Successfully', isError: false);
        _amountController.clear();
        _fetchData(); // Refresh to update "Handed Over" count
      }
    } catch (e) {
      debugPrint('Remit Error: $e');
      if (mounted) _showSnackBar('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          backgroundColor: isError ? Colors.red : Colors.green,
          behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWeb = width > 600;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Chip(
          label: Text('Technician Daily Summary',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.orange,
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : Center(
              child: Container(
                width: isWeb ? 600 : double.infinity,
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // 1. Date Selector
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<DateTime>(
                            value: _selectedDate,
                            isExpanded: true,
                            icon: const Icon(Icons.calendar_today,
                                color: Colors.orange),
                            items: _suitableDates.map((date) {
                              return DropdownMenuItem(
                                value: date,
                                child: Text(
                                  DateFormat('EEE, dd MMM yyyy').format(date),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500),
                                ),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _selectedDate = v);
                                _fetchData();
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 2. Status Card
                      _buildSummaryCard(children: [
                        _buildStatRow('Assigned', '$_totalAssigned'),
                        _buildStatRow('Cancelled', '$_totalCancelled',
                            color: Colors.red),
                        _buildStatRow('Finished', '$_totalFinished',
                            color: Colors.green),
                        _buildStatRow('Pending', '$_totalPending',
                            color: Colors.orange),
                      ]),
                      const SizedBox(height: 16),

                      // 3. Financial Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.blue.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4))
                          ],
                        ),
                        child: Column(
                          children: [
                            _buildStatRow(
                                'Collected', Util.formatMoney(_totalCollected),
                                isBold: true, color: Colors.white),
                            const Divider(color: Colors.white24),
                            _buildStatRow('Handed Over',
                                Util.formatMoney(_amountHandedOver),
                                isBold: true, color: Colors.white70),
                            const Divider(color: Colors.white24),
                            _buildStatRow(
                                'Accepted', Util.formatMoney(_amountAccepted),
                                isBold: true, color: Colors.white),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // 4. Remittance Input
                      if (_totalCollected > 0) ...[
                        TextField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Amount to Remit',
                            hintText: 'Enter amount given to manager',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.currency_rupee,
                                color: Colors.grey),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _submitRemittance,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.check_circle,
                                color: Colors.white),
                            label: const Text('Submit Remittance',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                          ),
                        ),
                      ] else
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text("No collection to remit for this date.",
                              style: TextStyle(color: Colors.grey)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryCard({required List<Widget> children}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: children.asMap().entries.map((entry) {
            int idx = entry.key;
            Widget w = entry.value;
            return Column(
              children: [
                w,
                if (idx < children.length - 1) const Divider(height: 24),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value,
      {Color? color, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 15,
                color: color != null &&
                        color != Colors.black87 &&
                        color != Colors.red &&
                        color != Colors.green &&
                        color != Colors.orange
                    ? color.withOpacity(0.9)
                    : Colors.grey.shade700,
                fontWeight: FontWeight.w600)),
        Text(value,
            style: TextStyle(
                fontSize: 16,
                color: color ?? Colors.black87,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500)),
      ],
    );
  }
}
