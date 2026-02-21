import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/features/add_work_order/add_work_order_page.dart';
import '../widgets/technician_daily_summary_dialog.dart';
import 'package:anderson_crm_flutter/components/price_view_page.dart';

import '../../theme/theme.dart';

import 'package:anderson_crm_flutter/features/core/widgets/common/common_widgets.dart';

import '../providers/technician_work_order_provider.dart';
import '../widgets/technician_actions.dart';
import '../widgets/technician_mobile_view.dart';
import '../widgets/technician_expanded_content.dart';

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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final notifier = ref.read(technicianWONotifierProvider.notifier);
      final storage = ref.read(storageServiceProvider);
      final techId =
          storage.getFromSession('logged_in_emp_id')?.toString() ?? '';

      await notifier.initialize();

      if (techId.isNotEmpty) {
        notifier.loadTechnicianWorkOrders(techId);
      }

      _checkSugarTestPrompt(storage);
    });
  }

  void _checkSugarTestPrompt(dynamic storage) {
    final sugarTestId = storage.getFromSession('sugar_tests')?.toString() ?? '';
    if (sugarTestId.isNotEmpty && mounted) {
      _showSugarTestDialog(sugarTestId);
    }
  }

  void _showSugarTestDialog(String docId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('Glucose (PP) Test',
            style: TextStyle(color: AppColors.primary)),
        content: Text('Do you want to book Glucose(PP) for this patient?'),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(storageServiceProvider).setSession('sugar_tests', '');
              Navigator.pop(ctx);
            },
            child: Text('No', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);

              ref.read(storageServiceProvider).setSession('sugar_tests', '');

              await _handleSugarTestCopy(docId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: Text('Yes'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSugarTestCopy(String docId) async {
    final notifier = ref.read(technicianWONotifierProvider.notifier);
    final workOrder = notifier.getWorkOrderById(docId);
    if (workOrder != null && mounted) {
      final workOrderForCopy = workOrder.copyWith(visitTime: '');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddWorkOrderPage(
            copyFrom: workOrderForCopy,
          ),
          fullscreenDialog: true,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Granular watches — only rebuild what changes
    final isInitializing = ref.watch(
      technicianWONotifierProvider.select((s) => s.isInitializing),
    );
    final isLoading = ref.watch(
      technicianWONotifierProvider.select((s) => s.isLoading),
    );
    final errorMessage = ref.watch(
      technicianWONotifierProvider.select((s) => s.errorMessage),
    );
    final workOrders = ref.watch(
      technicianWONotifierProvider.select((s) => s.workOrders),
    );

    // Sync status from separate StreamProvider — AppBar only
    final isConnected = ref.watch(techSyncStatusProvider).whenOrNull(
              data: (status) => status.connected,
            ) ??
        false;
    final isSyncing = ref.watch(techSyncStatusProvider).whenOrNull(
          data: (status) {
            final hasSynced = status.hasSynced ?? false;
            if (hasSynced) return status.downloading;
            return status.downloading || status.uploading;
          },
        ) ??
        false;

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
          // Connection indicator
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(
              isConnected ? Icons.cloud_done : Icons.cloud_off,
              color: isConnected ? AppColors.success : AppColors.error,
              size: 18,
            ),
          ),
          // Sync indicator
          if (isSyncing)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
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
            tooltip: 'Daily Summary',
            icon: const Icon(Icons.account_box_outlined, color: Colors.black87),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TechnicianDailySummaryDialog(),
                  fullscreenDialog: true,
                ),
              );
            },
          ),
        ],
      ),
      body: _buildBody(
        isInitializing: isInitializing,
        isLoading: isLoading,
        errorMessage: errorMessage,
        workOrders: workOrders,
      ),
    );
  }

  Widget _buildBody({
    required bool isInitializing,
    required bool isLoading,
    required String? errorMessage,
    required List<WorkOrder> workOrders,
  }) {
    if (isInitializing || (isLoading && workOrders.isEmpty)) {
      return _buildSkeletonLoading();
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: AppSizes.iconLg + 16, color: AppColors.error),
            SizedBox(height: AppSpacing.md),
            Text('Error: $errorMessage'),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;

        if (isMobile) {
          return TechnicianMobileView(
            workOrders: workOrders,
          );
        }

        return const VirtualTechnicianTable();
      },
    );
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
  const VirtualTechnicianTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use the derived provider — filter+sort is cached by Riverpod
    final filtered = ref.watch(techFilteredWorkOrdersPod);
    final sortCol = ref.watch(techSortColumnPod);
    final sortAsc = ref.watch(techSortAscendingPod);

    void handleSort(String sortKey) {
      if (sortCol == sortKey) {
        ref.read(techSortAscendingPod.notifier).state = !sortAsc;
      } else {
        ref.read(techSortColumnPod.notifier).state = sortKey;
        ref.read(techSortAscendingPod.notifier).state = true;
      }
    }

    return Column(
      children: [
        Padding(
          padding: AppPadding.md,
          child: WorkOrderSearchBar(
            hintText: 'Search Patient, Mobile, Bill No...',
            onChanged: (v) => ref.read(techSearchPod.notifier).state = v,
            padding: EdgeInsets.zero,
          ),
        ),
        Expanded(
          child: Card(
            margin: AppPadding.md,
            elevation: AppSizes.cardElevation,
            color: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
            child: Column(
              children: [
                Container(
                  padding: AppPadding.customTable,
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
                      const HeaderCell('Server', flex: 2),
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
              padding:
                  EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 2),
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
                  Expanded(
                      flex: 2,
                      child: ServerStatusChip(status: wo.serverStatus)),
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
          RepaintBoundary(
            child: TechnicianExpandedContent(workOrder: wo),
          ),
      ],
    );
  }

  Widget _buildCell(String text, {required int flex}) {
    return Expanded(
        flex: flex,
        child: Container(
            padding: AppPadding.sm,
            child: Text(text, overflow: TextOverflow.ellipsis)));
  }
}
