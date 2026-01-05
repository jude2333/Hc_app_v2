import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import '../add_work_order.dart';
import '../../../../screens/assign_technicians.dart';
import '../canceled_work_order_page.dart';
import '../../../../screens/tech_engagement_page.dart';
import '../../../../providers/work_order_provider.dart';
import '../../../../models/work_order.dart';
import '../../../features/price_list/screens/manager_price_view_page.dart';
import '../manager_tech_engagement_page.dart';

// Shared Widgets
import '../../widgets/common/common_widgets.dart';

// Manager-specific Widgets
import 'widgets/manager_actions.dart';
import 'widgets/manager_expanded_content.dart';

// State Providers
final todayPod = StateProvider<DateTime>((_) => DateTime(2022, 12, 14));
final selectedDatePod = StateProvider<DateTime>((ref) => ref.watch(todayPod));
final _searchPod = StateProvider<String>((_) => '');
final _sortColumnPod = StateProvider<String>((_) => 'date');
final _sortAscendingPod = StateProvider<bool>((_) => false);

final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

class WorkOrderPage2 extends ConsumerStatefulWidget {
  const WorkOrderPage2({Key? key}) : super(key: key);

  @override
  ConsumerState<WorkOrderPage2> createState() => _WorkOrderPageState();
}

class _WorkOrderPageState extends ConsumerState<WorkOrderPage2> {
  @override
  void initState() {
    super.initState();
    // ✅ OPTIMIZATION: Non-blocking initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = ref.read(workOrderProvider);
      if (provider.isInitializing) {
        provider.initialize(); // Don't await - let it run in background
      }
      // Load data after initialization completes automatically via provider
      final today = ref.read(todayPod);
      provider.loadWorkOrdersByDate(today);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(workOrderProvider);
    final selected = ref.watch(selectedDatePod);
    final today = ref.read(todayPod);

    final dateOffsets = [3, 2, 1, 0, -1, -2, -3, -4, -5];
    final dateChips = dateOffsets.map((off) {
      final date = today.add(Duration(days: off));
      String label;
      if (off == 3 || off == 2 || off <= -2) {
        label = _dateFormat.format(date);
      } else if (off == 1) {
        label = 'NEXTDAY\n${DateFormat('MM-dd').format(date)}';
      } else if (off == 0) {
        label = 'TODAY\n${DateFormat('MM-dd').format(date)}';
      } else {
        label = 'YESTERDAY\n${DateFormat('MM-dd').format(date)}';
      }
      return _DateChipProps(date, label);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 4,
        surfaceTintColor: Colors.white,
        title: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Work Orders',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              if (provider.isConnected)
                const Tooltip(
                    message: 'Connected',
                    child:
                        Icon(Icons.cloud_done, color: Colors.green, size: 20))
              else
                const Tooltip(
                    message: 'Offline',
                    child:
                        Icon(Icons.cloud_off, color: Colors.orange, size: 20)),
              if (provider.isSyncing)
                const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Cancelled',
            icon: const Icon(Icons.cancel_outlined, color: Colors.black87),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const CanceledWorkOrderPage())),
          ),
          IconButton(
            tooltip: 'Manage Prices',
            icon: const Icon(Icons.price_change, color: Colors.black87),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ManagerPriceViewPage()),
              );
            },
          ),
          IconButton(
            tooltip: 'Tech engagement',
            icon:
                const Icon(Icons.person_search_outlined, color: Colors.black87),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ManagerTechEngagementPage())),
          ),
          IconButton(
            tooltip: 'Add',
            icon: const Icon(Icons.add_circle_outline, color: Colors.black87),
            onPressed: () => _openAddEditPage(context, ref),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            color: Colors.white,
            height: 56,
            width: double.infinity,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: dateChips.length,
              itemBuilder: (_, idx) {
                final chip = dateChips[idx];
                final isSel = chip.date.year == selected.year &&
                    chip.date.month == selected.month &&
                    chip.date.day == selected.day;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ActionChip(
                    label: Text(chip.label, textAlign: TextAlign.center),
                    backgroundColor: isSel
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Colors.grey.shade100,
                    labelStyle: TextStyle(
                        color: isSel ? Colors.black : Colors.black87,
                        fontWeight:
                            isSel ? FontWeight.bold : FontWeight.normal),
                    onPressed: () async {
                      ref.read(selectedDatePod.notifier).state = chip.date;
                      await provider.loadWorkOrdersByDate(chip.date);
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        child: _buildBody(provider),
      ),
    );
  }

  Widget _buildBody(WorkOrderProvider provider) {
    // ✅ OPTIMIZATION: Show skeleton during initialization or loading
    if (provider.isInitializing ||
        (provider.isLoading && provider.workOrders.isEmpty)) {
      return _buildSkeletonLoading();
    }
    if (provider.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            Text('Error: ${provider.errorMessage}'),
            ElevatedButton(
              onPressed: () async {
                final today = ref.read(todayPod);
                await provider.loadWorkOrdersByDate(today);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    return VirtualManagerTable(rows: provider.workOrders);
  }

  // ✅ NEW: Skeleton loading for work order table
  Widget _buildSkeletonLoading() {
    return Column(
      children: [
        // Search bar skeleton
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 48,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        // Table skeleton
        Expanded(
          child: Card(
            elevation: 2,
            color: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Column(
              children: [
                // Header skeleton
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: Row(
                    children: List.generate(
                        8,
                        (index) => Expanded(
                              child: Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                height: 14,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            )),
                  ),
                ),
                // Row skeletons
                Expanded(
                  child: ListView.builder(
                    itemCount: 8,
                    itemBuilder: (context, index) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                        child: Row(
                          children: List.generate(
                              8,
                              (i) => Expanded(
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 4),
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  )),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _openAddEditPage(BuildContext context, WidgetRef ref) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
          builder: (context) => const AddWorkOrderPageMobile(),
          fullscreenDialog: true),
    )
        .then((value) async {
      if (value == 'refresh') {
        final selectedDate = ref.read(selectedDatePod);
        await ref.read(workOrderProvider).loadWorkOrdersByDate(selectedDate);
      }
    });
  }
}

/* ----------------------- VIRTUAL SORTABLE TABLE (MANAGER) ----------------------- */

class VirtualManagerTable extends ConsumerWidget {
  final List<WorkOrder> rows;
  const VirtualManagerTable({super.key, required this.rows});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(_searchPod);
    final sortCol = ref.watch(_sortColumnPod);
    final sortAsc = ref.watch(_sortAscendingPod);

    List<WorkOrder> filtered = search.isEmpty
        ? rows
        : rows.where((wo) {
            final term = search.toLowerCase();
            // Use pre-computed searchableText for fast filtering
            return wo.searchableText.contains(term);
          }).toList();

    filtered.sort((a, b) {
      int cmp = 0;
      switch (sortCol) {
        case 'name':
          cmp = a.patientName.compareTo(b.patientName);
          break;
        case 'status':
          cmp = a.status.compareTo(b.status);
          break;
        case 'date':
        default:
          cmp = a.visitDate.compareTo(b.visitDate);
          if (cmp == 0) cmp = a.visitTime.compareTo(b.visitTime);
          break;
      }
      return sortAsc ? cmp : -cmp;
    });

    void handleSort(String sortKey) {
      if (sortCol == sortKey) {
        ref.read(_sortAscendingPod.notifier).state = !sortAsc;
      } else {
        ref.read(_sortColumnPod.notifier).state = sortKey;
        ref.read(_sortAscendingPod.notifier).state = true;
      }
    }

    return Column(
      children: [
        WorkOrderSearchBar(
          hintText: 'Search',
          onChanged: (v) => ref.read(_searchPod.notifier).state = v,
        ),
        Expanded(
          child: Card(
            elevation: 2,
            color: Colors.white,
            margin: EdgeInsets.zero,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Column(
              children: [
                // Sticky Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8)),
                    border: Border(
                        bottom:
                            BorderSide(color: Colors.grey.shade300, width: 1)),
                  ),
                  child: Row(
                    children: [
                      const HeaderCell('No', flex: 1),
                      SortableHeader(
                        label: 'Name',
                        sortKey: 'name',
                        flex: 4,
                        currentSortColumn: sortCol,
                        isAscending: sortAsc,
                        onSort: handleSort,
                      ),
                      const HeaderCell('Gender', flex: 2),
                      const HeaderCell('Age', flex: 1),
                      const HeaderCell('Mobile', flex: 3),
                      SortableHeader(
                        label: 'Date',
                        sortKey: 'date',
                        flex: 3,
                        currentSortColumn: sortCol,
                        isAscending: sortAsc,
                        onSort: handleSort,
                      ),
                      const HeaderCell('Time', flex: 2),
                      SortableHeader(
                        label: 'Status',
                        sortKey: 'status',
                        flex: 3,
                        currentSortColumn: sortCol,
                        isAscending: sortAsc,
                        onSort: handleSort,
                      ),
                      const HeaderCell('Server Status', flex: 3),
                      const HeaderCell('Assigned To', flex: 4),
                      const Expanded(
                          flex: 3,
                          child: Text('Actions',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),

                // Virtual List
                Expanded(
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (ctx, i) =>
                        const Divider(height: 1, color: Colors.black12),
                    itemBuilder: (context, index) {
                      final wo = filtered[index];
                      return RepaintBoundary(
                        key: ValueKey(wo.id),
                        child: _ManagerExpandableRowConsumer(
                            workOrder: wo, index: index + 1),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/* ---------------- EXPANDABLE ROW (MANAGER) ---------------- */

class _ManagerExpandableRowConsumer extends ConsumerStatefulWidget {
  final WorkOrder workOrder;
  final int index;

  const _ManagerExpandableRowConsumer({
    required this.workOrder,
    required this.index,
    Key? key,
  }) : super(key: key);

  @override
  ConsumerState<_ManagerExpandableRowConsumer> createState() =>
      _ManagerExpandableRowConsumerState();
}

class _ManagerExpandableRowConsumerState
    extends ConsumerState<_ManagerExpandableRowConsumer> {
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
                  _buildCell('${widget.index}', flex: 1),
                  Expanded(
                    flex: 4,
                    child: NameWithBadges(
                      workOrder: wo,
                      layout: BadgeLayout.row,
                    ),
                  ),
                  _buildCell(wo.gender, flex: 2),
                  _buildCell(wo.age, flex: 1),
                  _buildCell(wo.mobile, flex: 3),
                  _buildCell(wo.formattedVisitDate, flex: 3),
                  _buildCell(wo.visitTime, flex: 2),
                  Expanded(
                    flex: 3,
                    child: StatusChip(
                      status: wo.status,
                      onTap: () => _showAssignDialog(context, wo),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: ServerChip(status: wo.serverStatus),
                  ),
                  _buildCell(wo.assignedTo, flex: 4),
                  Expanded(flex: 3, child: ManagerActions(workOrder: wo)),
                  SizedBox(
                      width: 40,
                      child: Icon(
                          _isExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 18,
                          color: Colors.grey)),
                ],
              ),
            ),
          ),
        ),
        if (_isExpanded) ManagerExpandedContent(workOrder: wo),
      ],
    );
  }

  Widget _buildCell(String text, {required int flex}) {
    return Expanded(
        flex: flex,
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Text(text, overflow: TextOverflow.ellipsis)));
  }

  void _showAssignDialog(BuildContext context, WorkOrder workOrder) {
    showAssignTechnicianDialog(context, ref, workOrder,
        (techId, techName) async {
      await _assignTechnician(context, workOrder, techId, techName);
    });
  }

  Future<void> _assignTechnician(BuildContext context, WorkOrder workOrder,
      String techId, String techName) async {
    final parentMessenger = ScaffoldMessenger.of(context);
    try {
      final provider = ref.read(workOrderProvider);
      final storage = ref.read(storageServiceProvider);
      final managerName = storage.getFromSession("logged_in_emp_name");

      final updatedOrder = workOrder.copyWith(
        assignedId: int.tryParse(techId) ?? 0,
        assignedTo: techName,
        status: 'assigned',
        lastUpdatedBy: managerName,
        lastUpdatedAt: DateTime.now(),
      );

      final now = DateTime.now();
      final formattedDate = DateFormat('MMMM dd, hh:mm a').format(now);
      final assignmentLog =
          "$formattedDate | $managerName | Assigned To $techName";
      final existingTimeline = List<String>.from(workOrder.timeLine);
      existingTimeline.add(assignmentLog);

      final customDoc = updatedOrder.buildDoc();
      customDoc['time_line'] = existingTimeline;

      await provider.updateWorkOrder(updatedOrder, customDoc: customDoc);

      if (context.mounted) {
        parentMessenger.showSnackBar(const SnackBar(
            content: Text('Technician assigned!'),
            backgroundColor: Colors.green));
        _showNotificationDialog(context, workOrder, techName, parentMessenger);
      }
    } catch (e) {
      if (context.mounted) {
        parentMessenger.showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _showNotificationDialog(BuildContext context, WorkOrder workOrder,
      String techName, ScaffoldMessengerState messenger) {
    bool sendSms = true;
    bool sendWhatsApp = true;
    bool sendEmail = workOrder.email.isNotEmpty;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Container(
                padding: const EdgeInsets.all(16),
                color: Colors.orange,
                child: const Text('Assigned Successfully',
                    style: TextStyle(color: Colors.white))),
            content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Do you wish to inform ${workOrder.patientName} (Mob: ${workOrder.mobile}) about the technician?'),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                      title: const Text('SMS'),
                      value: sendSms,
                      onChanged: (v) => setState(() => sendSms = v ?? false),
                      dense: true),
                  CheckboxListTile(
                      title: const Text('WhatsApp'),
                      value: sendWhatsApp,
                      onChanged: (v) =>
                          setState(() => sendWhatsApp = v ?? false),
                      dense: true),
                  CheckboxListTile(
                      title: const Text('Email'),
                      value: sendEmail,
                      onChanged: (v) => setState(() => sendEmail = v ?? false),
                      dense: true),
                ]),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Close')),
              TextButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  messenger.showSnackBar(const SnackBar(
                      content: Text('Notifications sent'),
                      backgroundColor: Colors.green));
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/* ---------------- HELPER CLASSES ---------------- */

class _DateChipProps {
  final DateTime date;
  final String label;
  _DateChipProps(this.date, this.label);
}
