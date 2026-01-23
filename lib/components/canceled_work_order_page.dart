import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:anderson_crm_flutter/config/settings.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/powersync/powersync_service.dart';

// Shared Widgets
import '../features/core/widgets/common/common_widgets.dart';
import 'package:anderson_crm_flutter/features/theme/theme.dart';

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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Cancelled Orders'),
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

                if (isMobile) {
                  return CancelledMobileView(workOrders: orders);
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

class CancelledMobileView extends ConsumerWidget {
  final List<WorkOrder> workOrders;

  const CancelledMobileView({
    super.key,
    required this.workOrders,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (workOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.assignment_outlined,
                size: 48,
                color: AppColors.textHint,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Canceled Orders',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a different date',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Results count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Text(
                '${workOrders.length} canceled orders',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        // Work order cards
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: workOrders.length,
            itemBuilder: (context, index) {
              return _MobileCancelledCard(
                workOrder: workOrders[index],
                index: index + 1,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MobileCancelledCard extends StatefulWidget {
  final WorkOrder workOrder;
  final int index;

  const _MobileCancelledCard({
    required this.workOrder,
    required this.index,
  });

  @override
  State<_MobileCancelledCard> createState() => _MobileCancelledCardState();
}

class _MobileCancelledCardState extends State<_MobileCancelledCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final wo = widget.workOrder;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.mdAll,
        side: BorderSide(
          color: _isExpanded ? AppColors.error : AppColors.divider,
          width: _isExpanded ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // Main card content (always visible)
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row: Index + Name + Expand icon
                  Row(
                    children: [
                      // Index badge
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: AppRadius.mdAll,
                        ),
                        child: Center(
                          child: Text(
                            '${widget.index}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Patient name + badges
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    wo.patientName,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${wo.gender} • ${wo.age} • ${wo.mobile}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Expand icon
                      AnimatedRotation(
                        turns: _isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Status chips row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          wo.status,
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.error,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ServerChip(status: wo.serverStatus),
                      const Spacer(),
                      // Visit time
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.access_time,
                                size: 12, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              wo.visitTime,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Expanded content
          if (_isExpanded)
            RepaintBoundary(
              child: Column(
                children: [
                  Divider(height: 1, color: AppColors.divider),
                  // Expanded details
                  _ExpandedContent(workOrder: wo),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
