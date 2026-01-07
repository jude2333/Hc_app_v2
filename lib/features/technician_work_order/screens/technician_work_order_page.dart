import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/powersync/screens/tech_engagement_page.dart';
import 'package:anderson_crm_flutter/powersync/screens/price_view_page.dart';

import '../../theme/theme.dart';

import 'package:anderson_crm_flutter/powersync/widgets/common/common_widgets.dart';

import '../providers/technician_work_order_provider.dart';
import '../widgets/technician_actions.dart';

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = ref.read(technicianWorkOrderProvider);
      final storage = ref.read(storageServiceProvider);
      final techId =
          storage.getFromSession('logged_in_emp_id')?.toString() ?? '';

      if (provider.isInitializing) {
        provider.initialize();
      }

      if (techId.isNotEmpty) {
        provider.loadTechnicianWorkOrders(techId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(technicianWorkOrderProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 1,
        title: Row(
          children: [
            Container(
              padding: AppPadding.badge,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: AppRadius.lgAll,
              ),
              child: Text(
                'My Work Orders',
                style: AppTextStyles.badge.copyWith(fontSize: 16),
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

  Widget _buildBody(TechnicianWorkOrderProvider provider) {
    if (provider.isInitializing ||
        (provider.isLoading && provider.workOrders.isEmpty)) {
      return _buildSkeletonLoading();
    }

    if (provider.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: AppSizes.iconLg + 16, color: AppColors.error),
            SizedBox(height: AppSpacing.md),
            Text('Error: ${provider.errorMessage}'),
          ],
        ),
      );
    }

    return VirtualTechnicianTable(rows: provider.workOrders);
  }

  Widget _buildSkeletonLoading() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.tableBorder,
              borderRadius: AppRadius.mdAll,
            ),
          ),
        ),
        Expanded(
          child: Card(
            margin: EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            elevation: AppSizes.cardElevation,
            color: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
            child: Column(
              children: [
                Container(
                  padding: AppPadding.tableCell,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
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
                                margin: EdgeInsets.symmetric(
                                    horizontal: AppSpacing.xs),
                                height: 14,
                                decoration: BoxDecoration(
                                  color: AppColors.tableBorder,
                                  borderRadius: AppRadius.xsAll,
                                ),
                              ),
                            )),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: 8,
                    itemBuilder: (context, index) {
                      return Container(
                        padding: AppPadding.tableCell,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: AppColors.divider),
                          ),
                        ),
                        child: Row(
                          children: List.generate(
                              7,
                              (i) => Expanded(
                                    child: Container(
                                      margin: EdgeInsets.symmetric(
                                          horizontal: AppSpacing.xs),
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: AppColors.tableBorder,
                                        borderRadius: AppRadius.xsAll,
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

class VirtualTechnicianTable extends ConsumerWidget {
  final List<WorkOrder> rows;
  const VirtualTechnicianTable({super.key, required this.rows});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(_searchPod);
    final sortCol = ref.watch(_sortColumnPod);
    final sortAsc = ref.watch(_sortAscendingPod);

    List<WorkOrder> filtered = search.isEmpty
        ? rows
        : rows.where((wo) {
            final term = search.toLowerCase();
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
        Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: WorkOrderSearchBar(
            hintText: 'Search Patient, Mobile, Bill No...',
            onChanged: (v) => ref.read(_searchPod.notifier).state = v,
            padding: EdgeInsets.zero,
          ),
        ),
        Expanded(
          child: Card(
            margin: EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            elevation: AppSizes.cardElevation,
            color: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                    border: Border(
                        bottom:
                            BorderSide(color: AppColors.tableBorder, width: 1)),
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
                      const Expanded(
                          flex: 3,
                          child: Text('Actions',
                              style: TextStyle(fontWeight: FontWeight.bold))),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text('No orders found',
                              style: TextStyle(color: AppColors.textHint)))
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (ctx, i) =>
                              Divider(height: 1, color: AppColors.divider),
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
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          hoverColor: AppColors.surfaceAlt,
          child: Container(
            decoration: BoxDecoration(
                border:
                    Border(bottom: BorderSide(color: AppColors.tableBorder))),
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.xs),
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
                          size: AppSizes.iconSm - 2,
                          color: AppColors.textHint)),
                ],
              ),
            ),
          ),
        ),
        if (_isExpanded)
          Container(
            padding: AppPadding.card,
            decoration: BoxDecoration(
              color: AppColors.background,
              border:
                  Border(left: BorderSide(color: AppColors.primary, width: 3)),
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
                  border: TableBorder.all(color: AppColors.tableBorder),
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: AppColors.surfaceAlt),
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

  Widget _buildCell(String text, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
