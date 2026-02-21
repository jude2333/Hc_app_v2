import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/components/assign_technicians.dart';

import '../../theme/theme.dart';
import '../../core/widgets/common/common_widgets.dart';
import '../providers/manager_work_order_provider.dart';
import '../controllers/manager_assignment_controller.dart';
import 'manager_actions.dart';
import 'manager_expanded_content.dart';

class ManagerDesktopView extends ConsumerStatefulWidget {
  final List<WorkOrder> workOrders;

  const ManagerDesktopView({super.key, required this.workOrders});

  @override
  ConsumerState<ManagerDesktopView> createState() => _ManagerDesktopViewState();
}

class _ManagerDesktopViewState extends ConsumerState<ManagerDesktopView> {
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sortCol = ref.watch(managerSortColumnPod);
    final sortAsc = ref.watch(managerSortAscendingPod);

    void handleSort(String sortKey) {
      if (sortCol == sortKey) {
        ref.read(managerSortAscendingPod.notifier).state = !sortAsc;
      } else {
        ref.read(managerSortColumnPod.notifier).state = sortKey;
        ref.read(managerSortAscendingPod.notifier).state = true;
      }
    }

    return Column(
      children: [
        WorkOrderSearchBar(
          hintText: 'Search',
          onChanged: (v) {
            _searchDebounce?.cancel();
            _searchDebounce = Timer(const Duration(milliseconds: 300), () {
              ref.read(managerSearchPod.notifier).state = v;
            });
          },
        ),
        Expanded(
          child: Card(
            elevation: AppSizes.cardElevation,
            color: AppColors.surface,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
            child: Column(
              children: [
                _buildTableHeader(sortCol, sortAsc, handleSort),
                Expanded(
                  child: widget.workOrders.isEmpty
                      ? Center(
                          child: Text('No Data Available',
                              style: TextStyle(color: AppColors.textSecondary)))
                      : ListView.separated(
                          itemCount: widget.workOrders.length,
                          cacheExtent: 500,
                          addAutomaticKeepAlives: false,
                          addRepaintBoundaries: true,
                          separatorBuilder: (ctx, i) =>
                              Divider(height: 1, color: AppColors.divider),
                          itemBuilder: (context, index) {
                            final wo = widget.workOrders[index];
                            return RepaintBoundary(
                              key: ValueKey(wo.id),
                              child: _ManagerExpandableRow(
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

  Widget _buildTableHeader(
      String sortCol, bool sortAsc, Function(String) handleSort) {
    return Container(
      // padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 2),
      padding: AppPadding.customTable,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8), topRight: Radius.circular(8)),
        border:
            Border(bottom: BorderSide(color: AppColors.tableBorder, width: 1)),
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
    );
  }
}

class _ManagerExpandableRow extends ConsumerStatefulWidget {
  final WorkOrder workOrder;
  final int index;

  const _ManagerExpandableRow({
    required this.workOrder,
    required this.index,
    super.key,
  });

  @override
  ConsumerState<_ManagerExpandableRow> createState() =>
      _ManagerExpandableRowState();
}

class _ManagerExpandableRowState extends ConsumerState<_ManagerExpandableRow>
    with AutomaticKeepAliveClientMixin {
  bool _isExpanded = false;

  @override
  bool get wantKeepAlive => _isExpanded;

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
                          size: AppSizes.iconSm - 2,
                          color: AppColors.textHint)),
                ],
              ),
            ),
          ),
        ),
        if (_isExpanded)
          RepaintBoundary(child: ManagerExpandedContent(workOrder: wo)),
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
      final controller = ref.read(managerAssignmentControllerProvider);
      final isReassignment = workOrder.assignedTo.isNotEmpty;

      final success = await controller.assignTechnician(
        workOrder: workOrder,
        techId: techId,
        techName: techName,
      );

      if (success && context.mounted) {
        parentMessenger.showSnackBar(SnackBar(
            content: Text('Technician assigned!'),
            backgroundColor: AppColors.success));
        _showNotificationDialog(
          context,
          workOrder,
          techId,
          techName,
          parentMessenger,
          isReassignment: isReassignment,
        );
      }
    } catch (e) {
      if (context.mounted) {
        parentMessenger.showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  void _showNotificationDialog(
    BuildContext context,
    WorkOrder workOrder,
    String techId,
    String techName,
    ScaffoldMessengerState messenger, {
    bool isReassignment = false,
  }) {
    // Capture controller BEFORE showing dialog to avoid ref-after-dispose.
    // The widget tree may rebuild (disposing this widget) while the dialog
    // is open, making ref.read() inside the callback crash.
    final controller = ref.read(managerAssignmentControllerProvider);

    bool sendSms = true;
    bool sendWhatsApp = true;
    bool sendEmail = workOrder.email.isNotEmpty;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Container(
                padding: AppPadding.card,
                color: AppColors.primary,
                child: Text('Assigned Successfully',
                    style: TextStyle(color: AppColors.textOnPrimary))),
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

                  try {
                    await controller.sendAssignmentMessages(
                      workOrder: workOrder,
                      techId: techId,
                      techName: techName,
                      sendSms: sendSms,
                      sendWhatsApp: sendWhatsApp,
                      sendEmail: sendEmail,
                      isReassignment: isReassignment,
                    );
                    messenger.showSnackBar(SnackBar(
                        content: Text('Notifications sent'),
                        backgroundColor: AppColors.success));
                  } catch (e) {
                    messenger.showSnackBar(SnackBar(
                        content: Text('Error sending notifications'),
                        backgroundColor: AppColors.error));
                  }
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
