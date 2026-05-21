import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/features/core/widgets/common/common_widgets.dart';

import 'package:anderson_crm_flutter/repositories/storage_repository.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import 'package:anderson_crm_flutter/features/core/widgets/file_viewer/file_viewer_exports.dart';
import 'package:anderson_crm_flutter/features/core/widgets/common/work_order_chips.dart';
import '../../theme/theme.dart';
import '../providers/billing_work_order_provider.dart';

class BillingDesktopTable extends ConsumerWidget {
  final List<WorkOrder> orders;
  final Function(WorkOrder) onBill;
  final Function(WorkOrder)? onSend;
  final bool showBillAction;

  const BillingDesktopTable({
    super.key,
    required this.orders,
    required this.onBill,
    this.onSend,
    this.showBillAction = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use the derived cached provider — filter+sort computed once,
    // recomputed only when orders, search, sortCol, or sortAsc change.
    final filtered = ref.watch(billingFilteredOrdersPod);
    final sortCol = ref.watch(billingSortColumnPod);
    final sortAsc = ref.watch(billingSortAscendingPod);

    void handleSort(String sortKey) {
      if (sortCol == sortKey) {
        ref.read(billingSortAscendingPod.notifier).state = !sortAsc;
      } else {
        ref.read(billingSortColumnPod.notifier).state = sortKey;
        ref.read(billingSortAscendingPod.notifier).state = true;
      }
    }

    return Padding(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          WorkOrderSearchBar(
            hintText: 'Search by name, mobile, bill number...',
            onChanged: (v) => ref.read(billingSearchPod.notifier).state = v,
          ),
          SizedBox(height: AppSpacing.md),
          Expanded(
            child: Card(
              elevation: AppSizes.cardElevation,
              color: AppColors.surface,
              margin: EdgeInsets.zero,
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
                            BorderSide(color: AppColors.tableBorder, width: 1),
                      ),
                    ),
                    child: Row(
                      children: [
                        const HeaderCell('No', flex: 1),
                        SortableHeader(
                          label: 'Name',
                          sortKey: 'name',
                          flex: 3,
                          currentSortColumn: sortCol,
                          isAscending: sortAsc,
                          onSort: handleSort,
                        ),
                        const HeaderCell('Mobile', flex: 2),
                        SortableHeader(
                          label: 'Date',
                          sortKey: 'date',
                          flex: 2,
                          currentSortColumn: sortCol,
                          isAscending: sortAsc,
                          onSort: handleSort,
                        ),
                        const HeaderCell('Time', flex: 1),
                        SortableHeader(
                          label: 'Total',
                          sortKey: 'total',
                          flex: 2,
                          currentSortColumn: sortCol,
                          isAscending: sortAsc,
                          onSort: handleSort,
                        ),
                        const HeaderCell('Assigned', flex: 2),
                        const HeaderCell('Tech Status', flex: 2),
                        const HeaderCell('Server Status', flex: 2),
                        if (showBillAction)
                          const HeaderCell('Actions', flex: 1),
                        const HeaderCell('Send', flex: 1),
                        const SizedBox(width: 40),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: AppColors.divider),
                      itemBuilder: (context, index) {
                        final order = filtered[index];
                        return RepaintBoundary(
                          key: ValueKey(order.id),
                          child: _BillingExpandableRow(
                            key: ValueKey('row_${order.id}'),
                            index: index + 1,
                            order: order,
                            onBill: onBill,
                            onSend: onSend,
                            showBillAction: showBillAction,
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
      ),
    );
  }
}

class _BillingExpandableRow extends StatefulWidget {
  final int index;
  final WorkOrder order;
  final Function(WorkOrder) onBill;
  final Function(WorkOrder)? onSend;
  final bool showBillAction;

  const _BillingExpandableRow({
    super.key,
    required this.index,
    required this.order,
    required this.onBill,
    this.onSend,
    required this.showBillAction,
  });

  @override
  State<_BillingExpandableRow> createState() => _BillingExpandableRowState();
}

class _BillingExpandableRowState extends State<_BillingExpandableRow>
    with AutomaticKeepAliveClientMixin {
  bool _isExpanded = false;

  @override
  bool get wantKeepAlive => _isExpanded;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final order = widget.order;

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          hoverColor: AppColors.surfaceAlt,
          child: Container(
            padding:
                EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 2),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.tableBorder)),
            ),
            child: Row(
              children: [
                _buildCell('${widget.index}', flex: 1),
                Expanded(
                  flex: 3,
                  child: NameWithBadges(
                    workOrder: order,
                    layout: BadgeLayout.row,
                  ),
                ),
                _buildCell(order.mobile, flex: 2, isPhoneNumber: true),
                _buildCell(order.formattedShortDate, flex: 2),
                _buildCell(order.visitTime, flex: 1),
                _buildCell(order.formattedCalculatedTotal, flex: 2),
                _buildCell(order.assignedTo, flex: 2),
                Expanded(flex: 2, child: StatusChip(status: order.status)),
                Expanded(
                    flex: 2, child: ServerChip(status: order.serverStatus)),
                if (widget.showBillAction)
                  Expanded(
                    flex: 1,
                    child: _canBill(order)
                        ? IconButton(
                            icon: Icon(Icons.receipt_long,
                                color: Colors.blue, size: AppSizes.iconSm),
                            tooltip: 'Bill Order',
                            onPressed: () => widget.onBill(order),
                          )
                        : const SizedBox(),
                  ),
                Expanded(
                  flex: 1,
                  child: _buildSendAction(order),
                ),
                SizedBox(
                  width: 40,
                  child: Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: AppSizes.iconSm - 2,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded) _ExpandedContent(order: order),
      ],
    );
  }

  Widget _buildCell(String text, {required int flex, bool isPhoneNumber = false}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
        child: CopyableText(text,
            overflow: TextOverflow.ellipsis,
            isPhoneNumber: isPhoneNumber),
      ),
    );
  }

  Widget _buildSendAction(WorkOrder order) {
    if (order.sentStatus == 'sent') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blue),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'sent',
          style: TextStyle(
            fontSize: 10,
            color: Colors.blue,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    if (_canSend(order)) {
      return IconButton(
        icon: Icon(Icons.send, color: AppColors.success, size: AppSizes.iconSm),
        tooltip: 'Send to Lab System',
        onPressed: () => widget.onSend?.call(order),
      );
    }

    return const SizedBox();
  }

  bool _canBill(WorkOrder order) {
    return order.status == 'Finished' && order.serverStatus == 'Received';
  }

  bool _canSend(WorkOrder order) {
    return order.status == 'Finished' &&
        order.serverStatus == 'Received' &&
        order.sentStatus != 'sent';
  }
}

class _ExpandedContent extends ConsumerWidget {
  final WorkOrder order;

  const _ExpandedContent({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ref.read — storageRepositoryProvider is a global singleton that never changes
    final storage = ref.read(storageRepositoryProvider);

    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      color: AppColors.surfaceAlt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailRow('Address', order.address),
          _DetailRow('Pincode', order.pincode),
          _DetailRow('Ref By', order.doctorName),
          if (order.prescriptionPhoto.isNotEmpty)
            _FileRow(
              label: 'Prescription',
              filePath: order.prescriptionPhoto,
              storage: storage,
            ),
          if (order.prescriptionPath.isNotEmpty)
            _FileRow(
              label: 'Prescription Photo',
              filePath: order.prescriptionPath,
              storage: storage,
            ),
          if (order.proformaPath.isNotEmpty)
            _FileRow(
              label: 'Proforma Invoice',
              filePath: order.proformaPath,
              storage: storage,
            ),
          if (order.billNumber.isNotEmpty)
            _DetailRow('Bill Number', order.billNumber),
          if (order.labNumber.isNotEmpty)
            _DetailRow('Lab Number', order.labNumber),
          SizedBox(height: AppSpacing.md),
          if (order.testItems.isNotEmpty) ...[
            Text('Test Items',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            SizedBox(height: AppSpacing.sm),
            _TestItemsTable(testItems: order.testItems),
            SizedBox(height: AppSpacing.sm),
            Text(
              'Total: ${order.formattedCalculatedTotal}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text('$label:',
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(child: CopyableText(value.isEmpty ? 'N/A' : value)),
        ],
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  final String label;
  final String filePath;
  final StorageRepository storage;

  const _FileRow({
    required this.label,
    required this.filePath,
    required this.storage,
  });

  @override
  Widget build(BuildContext context) {
    final fileName = FileService.getFileName(filePath);
    final fileCount = filePath.contains(',')
        ? '${filePath.split(',').length} files'
        : fileName;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text('$label:',
                style: const TextStyle(
                    fontWeight: FontWeight.w500, color: Colors.grey)),
          ),
          ActionLinkChip(
            label: fileCount,
            color: Colors.blue,
            onTap: () => _openFile(context),
          ),
        ],
      ),
    );
  }

  void _openFile(BuildContext context) {
    if (filePath.isEmpty) return;

    final files = filePath.contains(',')
        ? filePath.split(',').map((f) => f.trim()).toList()
        : [filePath];

    if (files.length == 1) {
      FileViewer.view(context, s3Path: files.first);
    } else {
      FilePickerDialog.show(
        context,
        files: files,
        title: 'View / Download Files',
        onAction: (selectedPath, action) {
          if (action == 'view') {
            FileViewer.view(context, s3Path: selectedPath);
          } else {
            final fileService = FileService(
              dio: Dio(),
              storage: storage,
            );
            fileService.downloadAndOpen(context, selectedPath);
          }
        },
      );
    }
  }
}

class _TestItemsTable extends StatelessWidget {
  final List<dynamic> testItems;

  const _TestItemsTable({required this.testItems});

  @override
  Widget build(BuildContext context) {
    return Table(
      border: TableBorder.all(color: AppColors.tableBorder),
      columnWidths: const {
        0: FlexColumnWidth(1),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(1),
        3: FlexColumnWidth(3),
        4: FlexColumnWidth(1),
        5: FlexColumnWidth(1),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: AppColors.primaryLight),
          children: const [
            _TableHeader('Dept ID'),
            _TableHeader('Dept Name'),
            _TableHeader('Invest ID'),
            _TableHeader('Investigation'),
            _TableHeader('Base Cost'),
            _TableHeader('Min Cost'),
          ],
        ),
        ...testItems.map((item) {
          final map = item as Map<String, dynamic>;
          return TableRow(
            children: [
              _TableCell(map['dept_id']?.toString() ?? ''),
              _TableCell(map['dept_name']?.toString() ?? ''),
              _TableCell(map['invest_id']?.toString() ?? ''),
              _TableCell(map['invest_name']?.toString() ?? ''),
              _TableCell('₹${map['base_cost']?.toString() ?? '0'}'),
              _TableCell('₹${map['min_cost']?.toString() ?? '0'}'),
            ],
          );
        }),
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String text;
  const _TableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(AppSpacing.sm),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  const _TableCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(AppSpacing.sm),
      child: Text(text, style: const TextStyle(fontSize: 11)),
    );
  }
}
