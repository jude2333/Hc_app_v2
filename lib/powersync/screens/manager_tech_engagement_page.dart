import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:anderson_crm_flutter/providers/manager_tech_engagement_provider.dart';

class ManagerTechEngagementPage extends ConsumerStatefulWidget {
  const ManagerTechEngagementPage({Key? key}) : super(key: key);

  @override
  ConsumerState<ManagerTechEngagementPage> createState() =>
      _ManagerTechEngagementPageState();
}

class _ManagerTechEngagementPageState
    extends ConsumerState<ManagerTechEngagementPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(managerTechEngagementProvider.notifier).loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(managerTechEngagementProvider);
    final notifier = ref.read(managerTechEngagementProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text(
            'Technician Engagements',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.black54),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 1. Controls Row: Date + Month Toggle
            _buildControlsRow(state, notifier),
            const SizedBox(height: 12),

            // 2. Aggregates Card
            if (!state.isLoading) _buildAggregatesCard(state.aggregates),
            const SizedBox(height: 12),

            // 3. Search Bar
            _buildSearchBar(notifier),
            const SizedBox(height: 12),

            // 4. Main Table Card
            Expanded(
              child: Card(
                elevation: 2,
                color: Colors.white,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildTableHeader(),
                    Expanded(
                      child: state.isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.orange))
                          : ListView.separated(
                              itemCount: state.filteredList.length,
                              separatorBuilder: (_, __) => const Divider(
                                  height: 1, color: Colors.black12),
                              itemBuilder: (context, index) {
                                return _TechRow(
                                    summary: state.filteredList[index]);
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsRow(ManagerTechEngagementState state,
      ManagerTechEngagementNotifier notifier) {
    return Row(
      children: [
        // Date Picker Button
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: state.selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
              helpText: state.isMonthWise ? "SELECT MONTH" : "SELECT DATE",
            );
            if (picked != null) notifier.setDate(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today,
                    size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  state.isMonthWise
                      ? DateFormat('yyyy-MM').format(state.selectedDate)
                      : DateFormat('yyyy-MM-dd').format(state.selectedDate),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),

        // Month Toggle
        Row(
          children: [
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: state.isMonthWise,
                onChanged: (val) => notifier.toggleMonthWise(val),
                activeColor: Colors.orange,
              ),
            ),
            Text(
              "Month Wise",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildAggregatesCard(AggregateSummary agg) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Blue Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF2196F3),
              borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: const Text(
              "Aggregates",
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Stats Row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            color: Colors.grey.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _AggCell("Assigned", "${agg.totalAssigned}"),
                _AggCell("Cancelled", "${agg.totalCancelled}",
                    color: Colors.red),
                _AggCell("Finished", "${agg.totalFinished}",
                    color: Colors.green),
                _AggCell("Pending", "${agg.totalPending}",
                    color: Colors.orange),
                _AggCell("Cash", "${agg.totalCash.toInt()}"),
                _AggCell("GPay", "${agg.totalGpay.toInt()}"),
                _AggCell("HC", "${agg.totalHcCharges.toInt()}"),
                _AggCell("Collected", "${agg.totalCollected.toInt()}"),
                _AggCell("Received", "${agg.totalReceived.toInt()}",
                    color: Colors.blue),
              ],
            ),
          ),
          // Total Excluding
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                const Text(
                  "Total Cases Excluding Glucose(PP)",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    "${agg.totalAccounted}",
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ManagerTechEngagementNotifier notifier) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: "Search technician...",
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey.shade400),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
        onChanged: notifier.search,
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: const Row(
        children: [
          _HeaderCell("Technician", flex: 1),
          _HeaderCell("Assigned", flex: 1),
          _HeaderCell("Cancelled", flex: 1),
          _HeaderCell("Finished", flex: 1),
          _HeaderCell("Pending", flex: 1),
          _HeaderCell("Appt Till", flex: 1),
          _HeaderCell("Cash", flex: 1),
          _HeaderCell("GPay", flex: 1),
          _HeaderCell("HC", flex: 1),
          _HeaderCell("Total", flex: 1),
          _HeaderCell("Received", flex: 1),
          SizedBox(width: 32),
        ],
      ),
    );
  }
}

// ============================================================================
// TECH ROW
// ============================================================================

class _TechRow extends StatefulWidget {
  final TechSummary summary;
  const _TechRow({Key? key, required this.summary}) : super(key: key);

  @override
  State<_TechRow> createState() => _TechRowState();
}

class _TechRowState extends State<_TechRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    if (s.assigned == 0) return const SizedBox.shrink();

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          hoverColor: Colors.grey.shade100,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _expanded ? Colors.orange.shade50 : Colors.white,
            ),
            child: Row(
              children: [
                _DataCell(s.name, flex: 1, bold: true),
                _DataCell("${s.assigned}", flex: 1),
                _DataCell("${s.cancelled}", flex: 1, color: Colors.red),
                _DataCell("${s.finished}", flex: 1, color: Colors.green),
                _DataCell("${s.pending}", flex: 1, color: Colors.orange),
                _DataCell(s.timeTill, flex: 1),
                _DataCell("${s.cash.toInt()}", flex: 1),
                _DataCell("${s.gpay.toInt()}", flex: 1),
                _DataCell("${s.hcCharges.toInt()}", flex: 1),
                _DataCell("${s.totalAmount.toInt()}", flex: 1),
                _DataCell("${s.amountCollected.toInt()}",
                    flex: 1, color: Colors.blue),
                SizedBox(
                  width: 32,
                  child: Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_expanded) _PatientTable(orders: widget.summary.orders),
      ],
    );
  }
}

// ============================================================================
// PATIENT EXPANDED TABLE
// ============================================================================

class _PatientTable extends StatelessWidget {
  final List<Map<String, dynamic>> orders;
  const _PatientTable({required this.orders});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Inner Header - Light Orange
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Row(
              children: [
                _HeaderCell("Patient", flex: 1),
                _HeaderCell("Gender", flex: 1),
                _HeaderCell("Age", flex: 1),
                _HeaderCell("Mobile", flex: 1),
                _HeaderCell("Time", flex: 1),
                _HeaderCell("Status", flex: 1, align: TextAlign.center),
                _HeaderCell("HC", flex: 1),
                _HeaderCell("Amt", flex: 1),
                _HeaderCell("Remit", flex: 1, align: TextAlign.center),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Patient Rows
          ...orders.map((order) => _PatientRow(order: order)).toList(),
        ],
      ),
    );
  }
}

class _PatientRow extends ConsumerWidget {
  final Map<String, dynamic> order;
  const _PatientRow({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doc = jsonDecode(order['doc'] ?? '{}');
    final accepted = doc['accept_remittance'] == true;
    final amount =
        double.tryParse(order['received_amount']?.toString() ?? '0') ?? 0;
    final paymentMethod = doc['payment_method']?.toString() ?? 'cash';
    final isCash = paymentMethod == 'cash' && amount > 0;
    final hcCharges = doc['hc_charges']?.toString() ?? '0';
    final status = order['status'] ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          _DataCell(order['patient_name'] ?? '', flex: 1),
          _DataCell(doc['gender']?.toString() ?? '', flex: 1),
          _DataCell(doc['age']?.toString() ?? '', flex: 1),
          _DataCell(doc['mobile']?.toString() ?? '', flex: 1),
          _DataCell(order['visit_time']?.toString() ?? '', flex: 1),
          // Status Chip (Compact)
          Expanded(
            flex: 1,
            child: Center(
              child: _StatusChip(status: status),
            ),
          ),

          _DataCell(hcCharges, flex: 1),
          _DataCell("${amount.toInt()}", flex: 1),
          // Remittance Toggle (Compact)
          Expanded(
            flex: 1,
            child: Center(
              child: isCash
                  ? _RemittanceToggle(
                      accepted: accepted,
                      onToggle: () {
                        ref
                            .read(managerTechEngagementProvider.notifier)
                            .toggleRemittance(order['id'].toString(), accepted);
                      },
                    )
                  : Text(
                      paymentMethod == 'gpay' ? "GP" : "Cr",
                      style:
                          TextStyle(fontSize: 9, color: Colors.grey.shade500),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// HELPER WIDGETS (Compact & Modern)
// ============================================================================

class _AggCell extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _AggCell(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color ?? Colors.black87)),
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final int flex;
  final TextAlign align;

  const _HeaderCell(
    this.text, {
    required this.flex,
    this.align = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        flex: flex,
        child: Text(
          text,
          textAlign: align,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: Colors.grey.shade700,
          ),
        ),
      );
}

class _DataCell extends StatelessWidget {
  final String text;
  final int flex;
  final bool bold;
  final Color? color;
  final TextAlign align;

  const _DataCell(
    this.text, {
    required this.flex,
    this.bold = false,
    this.color,
    this.align = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        flex: flex,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            text,
            textAlign: align,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
              color: color ?? Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color chipColor;
    if (status == 'Finished') {
      chipColor = Colors.green;
    } else if (status == 'cancelled' || status == 'Cancelled') {
      chipColor = Colors.red;
    } else {
      chipColor = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        border: Border.all(color: chipColor, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
            fontSize: 12, color: chipColor, fontWeight: FontWeight.w600),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _RemittanceToggle extends StatelessWidget {
  final bool accepted;
  final VoidCallback onToggle;
  const _RemittanceToggle({required this.accepted, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color:
              accepted ? Colors.green.withOpacity(0.1) : Colors.grey.shade100,
          border: Border.all(
            color: accepted ? Colors.green : Colors.grey.shade400,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              accepted ? Icons.check_circle : Icons.circle_outlined,
              size: 11,
              color: accepted ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 3),
            Text(
              accepted ? "Yes" : "No",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: accepted ? Colors.green : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
