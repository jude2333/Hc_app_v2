import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import 'package:anderson_crm_flutter/providers/work_order_provider.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import '../tech_engagement_page.dart';
import '../price_view_page.dart';

// Shared Widgets
import '../../widgets/common/common_widgets.dart';

// Technician-specific Widgets
import 'widgets/technician_actions.dart';

// State Providers
final _searchPod = StateProvider<String>((_) => '');
final _sortColumnPod = StateProvider<String>((_) => 'date');
final _sortAscendingPod = StateProvider<bool>((_) => false);

class TechnicianWorkOrderPage extends ConsumerStatefulWidget {
  const TechnicianWorkOrderPage({Key? key}) : super(key: key);

  @override
  ConsumerState<TechnicianWorkOrderPage> createState() =>
      _TechnicianWorkOrderPageState();
}

class _TechnicianWorkOrderPageState
    extends ConsumerState<TechnicianWorkOrderPage> {
  @override
  void initState() {
    super.initState();
    // ✅ OPTIMIZATION: Non-blocking initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = ref.read(workOrderProvider);
      final storage = ref.read(storageServiceProvider);
      final techId =
          storage.getFromSession('logged_in_emp_id')?.toString() ?? '';

      if (provider.isInitializing) {
        provider.initialize(); // Don't await - let it run in background
      }

      if (techId.isNotEmpty) {
        provider.loadTechnicianWorkOrders(techId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(workOrderProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'My Work Orders',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Price view',
            icon: const Icon(Icons.list_alt_outlined, color: Colors.black87),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PriceViewPage(),
                  fullscreenDialog: true,
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Tech Engagements',
            icon: const Icon(Icons.account_box_outlined, color: Colors.black87),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TechEngagementPage(),
                  fullscreenDialog: true,
                ),
              );
            },
          ),
        ],
      ),
      body: _buildBody(provider),
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
            const SizedBox(height: 16),
            Text('Error: ${provider.errorMessage}'),
          ],
        ),
      );
    }

    return VirtualWorkOrderTable(rows: provider.workOrders);
  }

  // ✅ NEW: Skeleton loading for technician work order table
  Widget _buildSkeletonLoading() {
    return Column(
      children: [
        // Search bar skeleton
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        // Table skeleton
        Expanded(
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        7,
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
                              7,
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
}

/* ----------------------- VIRTUAL SORTABLE TABLE ----------------------- */

class VirtualWorkOrderTable extends ConsumerWidget {
  final List<WorkOrder> rows;
  const VirtualWorkOrderTable({super.key, required this.rows});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(_searchPod);
    final sortCol = ref.watch(_sortColumnPod);
    final sortAsc = ref.watch(_sortAscendingPod);

    // 1. Filter using pre-computed searchableText
    List<WorkOrder> filtered = search.isEmpty
        ? rows
        : rows.where((wo) {
            final term = search.toLowerCase();
            return wo.searchableText.contains(term);
          }).toList();

    // 2. Sort
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
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: WorkOrderSearchBar(
            hintText: 'Search Patient, Mobile, Bill No...',
            onChanged: (v) => ref.read(_searchPod.notifier).state = v,
            padding: EdgeInsets.zero,
          ),
        ),

        // Virtual Table
        Expanded(
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 2,
            color: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                    border: Border(
                        bottom:
                            BorderSide(color: Colors.grey.shade300, width: 1)),
                  ),
                  child: Row(
                    children: [
                      SortableHeader(
                        label: 'Name',
                        sortKey: 'name',
                        flex: 4,
                        currentSortColumn: sortCol,
                        isAscending: sortAsc,
                        onSort: handleSort,
                      ),
                      SortableHeader(
                        label: 'Gender',
                        sortKey: '',
                        flex: 2,
                        currentSortColumn: sortCol,
                        isAscending: sortAsc,
                        onSort: handleSort,
                      ),
                      SortableHeader(
                        label: 'Age',
                        sortKey: '',
                        flex: 1,
                        currentSortColumn: sortCol,
                        isAscending: sortAsc,
                        onSort: handleSort,
                      ),
                      SortableHeader(
                        label: 'Mobile',
                        sortKey: '',
                        flex: 3,
                        currentSortColumn: sortCol,
                        isAscending: sortAsc,
                        onSort: handleSort,
                      ),
                      SortableHeader(
                        label: 'Date',
                        sortKey: 'date',
                        flex: 3,
                        currentSortColumn: sortCol,
                        isAscending: sortAsc,
                        onSort: handleSort,
                      ),
                      SortableHeader(
                        label: 'Time',
                        sortKey: '',
                        flex: 2,
                        currentSortColumn: sortCol,
                        isAscending: sortAsc,
                        onSort: handleSort,
                      ),
                      SortableHeader(
                        label: 'Status',
                        sortKey: 'status',
                        flex: 3,
                        currentSortColumn: sortCol,
                        isAscending: sortAsc,
                        onSort: handleSort,
                      ),
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
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text('No orders found',
                              style: TextStyle(color: Colors.grey)))
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (ctx, i) =>
                              const Divider(height: 1, color: Colors.black12),
                          itemBuilder: (context, index) {
                            return RepaintBoundary(
                              child: _TechnicianExpandableRow(
                                  workOrder: filtered[index]),
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

/* ---------------- EXPANDABLE ROW ---------------- */

class _TechnicianExpandableRow extends StatefulWidget {
  final WorkOrder workOrder;
  const _TechnicianExpandableRow({required this.workOrder});

  @override
  State<_TechnicianExpandableRow> createState() =>
      _TechnicianExpandableRowState();
}

class _TechnicianExpandableRowState extends State<_TechnicianExpandableRow> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final wo = widget.workOrder;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main Row
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
                  Expanded(flex: 3, child: StatusChip(status: wo.status)),
                  Expanded(flex: 3, child: TechnicianActions(workOrder: wo)),
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

        // Expanded Content (Horizontal Table)
        if (_isExpanded)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: const Border(
                  left: BorderSide(color: Colors.orange, width: 3)),
            ),
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2),
                    1: FlexColumnWidth(1),
                    2: FlexColumnWidth(3),
                    3: FlexColumnWidth(2),
                    4: FlexColumnWidth(2),
                  },
                  border: TableBorder.all(color: Colors.grey.shade300),
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: Colors.grey.shade200),
                      children: const [
                        WOTableHeader('Address'),
                        WOTableHeader('Pincode'),
                        WOTableHeader('Additional Info'),
                        WOTableHeader('Status'),
                        WOTableHeader('Assigned To'),
                      ],
                    ),
                    TableRow(
                      children: [
                        WOTableCell(wo.address),
                        WOTableCell(wo.pincode),
                        WOTableCell(wo.freeText.isEmpty ? 'N/A' : wo.freeText),
                        WOTableCell(wo.status),
                        WOTableCell(wo.assignedTo),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCell(String text, {required int flex, bool isBold = false}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style:
            TextStyle(fontWeight: isBold ? FontWeight.w600 : FontWeight.normal),
      ),
    );
  }
}
