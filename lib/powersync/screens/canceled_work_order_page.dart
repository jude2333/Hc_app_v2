import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:anderson_crm_flutter/config/settings.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/powersync/powersync_service.dart';

// Shared Widgets
import '../widgets/common/common_widgets.dart';

final cancelledDatePod = StateProvider<DateTime>((ref) {
  return Settings.development ? DateTime(2022, 12, 14) : DateTime.now();
});

final cancelledOrdersProvider =
    StreamProvider.autoDispose<List<WorkOrder>>((ref) {
  final date = ref.watch(cancelledDatePod);
  final service = ref.watch(powerSyncServiceProvider);

  return service.watchCancelledWorkOrdersByDate(date).map((rows) {
    return rows.map((row) => WorkOrder.fromRow(row)).toList();
  });
});

class CanceledWorkOrderPage extends ConsumerStatefulWidget {
  const CanceledWorkOrderPage({Key? key}) : super(key: key);

  @override
  ConsumerState<CanceledWorkOrderPage> createState() =>
      _CanceledWorkOrderPageState();
}

class _CanceledWorkOrderPageState extends ConsumerState<CanceledWorkOrderPage> {
  List<DateTime> _suitableDates = [];

  @override
  void initState() {
    super.initState();
    _generateDates();
  }

  void _generateDates() {
    final DateTime baseDate =
        Settings.development ? DateTime(2022, 12, 14) : DateTime.now();

    _suitableDates =
        List.generate(7, (i) => baseDate.subtract(Duration(days: i - 1)));
  }

  @override
  Widget build(BuildContext context) {
    final asyncOrders = ref.watch(cancelledOrdersProvider);
    final selectedDate = ref.watch(cancelledDatePod);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text(
            'Cancelled Orders',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ),
      body: Column(
        children: [
          // 1. Date Selector
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text("Select Date:  ",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.grey)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<DateTime>(
                      value: _suitableDates.contains(selectedDate)
                          ? selectedDate
                          : _suitableDates[1], // Fallback to today
                      icon: const Icon(Icons.calendar_today,
                          size: 18, color: Colors.red),
                      items: _suitableDates.map((date) {
                        return DropdownMenuItem(
                          value: date,
                          child:
                              Text(DateFormat('EEE, dd MMM yyyy').format(date)),
                        );
                      }).toList(),
                      onChanged: (newDate) {
                        if (newDate != null) {
                          ref.read(cancelledDatePod.notifier).state = newDate;
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Content
          Expanded(
            child: asyncOrders.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: Colors.red)),
              error: (err, stack) => Center(child: Text('Error: $err')),
              data: (orders) {
                if (orders.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No cancelled orders for this date',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }
                return VirtualCancelledTable(rows: orders);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class VirtualCancelledTable extends StatelessWidget {
  final List<WorkOrder> rows;
  const VirtualCancelledTable({Key? key, required this.rows}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: Colors.white,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8), topRight: Radius.circular(8)),
              border: Border(
                  bottom: BorderSide(color: Colors.grey.shade300, width: 1)),
            ),
            child: const Row(
              children: [
                FlexHeaderCell('No', flex: 1),
                FlexHeaderCell('Name', flex: 4),
                FlexHeaderCell('Gender', flex: 2),
                FlexHeaderCell('Age', flex: 1),
                FlexHeaderCell('Mobile', flex: 3),
                FlexHeaderCell('Time', flex: 2),
                FlexHeaderCell('Status', flex: 3),
                FlexHeaderCell('Assigned To', flex: 4),
                SizedBox(width: 40), // Icon space
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (ctx, i) =>
                  const Divider(height: 1, color: Colors.black12),
              itemBuilder: (context, index) {
                return RepaintBoundary(
                  child: _CancelledExpandableRow(
                      workOrder: rows[index], index: index + 1),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CancelledExpandableRow extends StatefulWidget {
  final WorkOrder workOrder;
  final int index;
  const _CancelledExpandableRow({required this.workOrder, required this.index});

  @override
  State<_CancelledExpandableRow> createState() =>
      _CancelledExpandableRowState();
}

class _CancelledExpandableRowState extends State<_CancelledExpandableRow> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final wo = widget.workOrder;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          hoverColor: Colors.grey.shade100,
          child: Container(
            decoration: BoxDecoration(
                border:
                    Border(bottom: BorderSide(color: Colors.grey.shade300))),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Row(
                children: [
                  FlexDataCell('${widget.index}', flex: 1),
                  Expanded(
                    flex: 4,
                    child: NameWithBadges(
                      workOrder: wo,
                      layout: BadgeLayout.row,
                    ),
                  ),
                  FlexDataCell(wo.gender, flex: 2),
                  FlexDataCell(wo.age, flex: 1),
                  FlexDataCell(wo.mobile, flex: 3),
                  FlexDataCell(wo.visitTime, flex: 2),
                  FlexDataCell(wo.status, flex: 3, color: Colors.red),
                  FlexDataCell(wo.assignedTo, flex: 4),

                  // Expand Icon
                  SizedBox(
                    width: 40,
                    child: Icon(
                      _isExpanded
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
        ),
        if (_isExpanded) _ExpandedContent(workOrder: wo),
      ],
    );
  }
}

class _ExpandedContent extends StatelessWidget {
  final WorkOrder workOrder;
  const _ExpandedContent({required this.workOrder});

  @override
  Widget build(BuildContext context) {
    final reason = workOrder.parsedDoc['cancel_reason'] ?? 'No reason provided';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: const Border(left: BorderSide(color: Colors.red, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Details Table
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(3),
              3: FlexColumnWidth(2)
            },
            border: TableBorder.all(color: Colors.grey.shade300),
            children: [
              TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade200),
                  children: const [
                    WOTableHeader('Address'),
                    WOTableHeader('Pincode'),
                    WOTableHeader('Additional Info'),
                    WOTableHeader('Ref. By'),
                  ]),
              TableRow(children: [
                WOTableCell(workOrder.address),
                WOTableCell(workOrder.pincode),
                WOTableCell(workOrder.freeText),
                WOTableCell(workOrder.doctorName),
              ]),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              const Text("Cancellation Reason: ",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.red)),
              Expanded(
                  child: Text(reason,
                      style: const TextStyle(fontWeight: FontWeight.w500))),
            ],
          ),
        ],
      ),
    );
  }
}
