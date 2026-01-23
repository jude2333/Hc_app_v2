import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/features/add_work_order/add_work_order_page.dart';
import 'package:anderson_crm_flutter/components/cancel_work_order_dialog.dart';
import 'package:anderson_crm_flutter/features/hc_process/screens/hc_process_page.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import '../../theme/theme.dart';
import '../../core/widgets/common/common_widgets.dart';
import '../providers/technician_work_order_provider.dart';
import 'technician_expanded_content.dart';

class TechnicianMobileView extends ConsumerWidget {
  final List<WorkOrder> workOrders;
  final String searchQuery;
  final Function(String) onSearchChanged;

  const TechnicianMobileView({
    super.key,
    required this.workOrders,
    required this.searchQuery,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtered = searchQuery.isEmpty
        ? workOrders
        : workOrders.where((wo) {
            final term = searchQuery.toLowerCase();
            return wo.searchableText.contains(term);
          }).toList();

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: WorkOrderSearchBar(
            hintText: 'Search Patient, Mobile...',
            onChanged: onSearchChanged,
            padding: EdgeInsets.zero,
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text('No orders found',
                      style: TextStyle(color: AppColors.textHint)))
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    return _TechnicianMobileCard(workOrder: filtered[index]);
                  },
                ),
        ),
      ],
    );
  }
}

class _TechnicianMobileCard extends ConsumerStatefulWidget {
  final WorkOrder workOrder;

  const _TechnicianMobileCard({required this.workOrder});

  @override
  ConsumerState<_TechnicianMobileCard> createState() =>
      _TechnicianMobileCardState();
}

class _TechnicianMobileCardState extends ConsumerState<_TechnicianMobileCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final wo = widget.workOrder;
    final clientStatus = _getClientStatus(wo);

    return Card(
      margin: EdgeInsets.only(bottom: AppSpacing.sm),
      elevation: 2,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with name and badges
          Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${wo.patientName} [${wo.age} / ${wo.gender}]',
                              style: AppTextStyles.h3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (wo.status != 'cancelled' &&
                              wo.status != 'Finished')
                            Padding(
                              padding: EdgeInsets.only(left: AppSpacing.xs),
                              child: Icon(Icons.edit,
                                  size: 14, color: AppColors.success),
                            ),
                        ],
                      ),
                      if (clientStatus.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: AppSpacing.xs),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xs),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.1),
                              borderRadius: AppRadius.smAll,
                            ),
                            child: Text(
                              clientStatus,
                              style: TextStyle(
                                  color: AppColors.error,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Simple table rows
          _buildInfoTable(wo),

          // Actions row
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              border:
                  Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
            ),
            child: Row(
              children: [
                _buildActionChip('Copy', () => _onCopy(context)),
                if (wo.status != 'cancelled' &&
                    wo.status != 'Finished' &&
                    wo.status != 'NA') ...[
                  SizedBox(width: AppSpacing.xs),
                  _buildActionChip('Start', () => _onStart(context),
                      color: AppColors.success),
                  SizedBox(width: AppSpacing.xs),
                  _buildActionChip('Cancel', () => _onCancel(context),
                      color: AppColors.error),
                ],
                if (wo.serverStatus.isNotEmpty && wo.serverStatus != 'NA') ...[
                  SizedBox(width: AppSpacing.xs),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: _getServerStatusColor(wo.serverStatus)),
                      borderRadius: AppRadius.smAll,
                    ),
                    child: Text(
                      _getServerStatusText(wo.serverStatus),
                      style: TextStyle(
                        fontSize: 11,
                        color: _getServerStatusColor(wo.serverStatus),
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                IconButton(
                  icon: Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.chevron_right,
                    color: AppColors.textHint,
                  ),
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

          // Expanded content
          if (_isExpanded)
            RepaintBoundary(
              child: TechnicianExpandedContent(workOrder: wo),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoTable(WorkOrder wo) {
    final isCancelled = wo.status == 'cancelled' || wo.status == 'NA';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(3),
        },
        children: [
          _tableRow('Mobile', wo.mobile),
          _tableRow('App. Time', '${wo.formattedVisitDate} ${wo.visitTime}'),
          _tableRow('My Status', '',
              statusWidget: StatusChip(status: wo.status)),
          if (!isCancelled) ...[
            _tableRow('Test Items',
                wo.parsedDoc['test_items'] != null ? 'View' : 'Nil',
                isViewable: wo.parsedDoc['test_items'] != null),
            _tableRow('GPay', _getGPayDisplay(wo)),
            _tableRow(
                'Prescription',
                wo.prescriptionPath.isNotEmpty
                    ? _getFileName(wo.prescriptionPath)
                    : 'Nil'),
          ],
        ],
      ),
    );
  }

  TableRow _tableRow(String label, String value,
      {Widget? statusWidget, bool isViewable = false}) {
    return TableRow(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Text(label,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: statusWidget ??
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  color: isViewable ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: isViewable ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildActionChip(String label, VoidCallback onTap, {Color? color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.smAll,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          border: Border.all(color: color ?? AppColors.primary),
          borderRadius: AppRadius.smAll,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color ?? AppColors.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String _getClientStatus(WorkOrder wo) {
    List<String> parts = [];
    if (wo.urgent) parts.add('Urgent');
    if (wo.vip) parts.add('VIP');
    if (wo.credit == 1) parts.add('Credit');
    if (wo.credit == 2) parts.add('Trial');
    if (wo.b2bClientId != null && wo.b2bClientId! > 0) parts.add('B2B');
    return parts.join(' ');
  }

  String _getGPayDisplay(WorkOrder wo) {
    final gpayRef = wo.parsedDoc['gpay_ref']?.toString() ?? '';
    if (wo.status == 'Finished' && gpayRef == 'Later') {
      return 'Edit';
    }
    return gpayRef.isEmpty ? 'Nil' : gpayRef;
  }

  String _getFileName(String path) {
    if (path.contains('/')) {
      return path.substring(path.lastIndexOf('/') + 1);
    }
    return path;
  }

  Color _getServerStatusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('not') || s.isEmpty) return AppColors.error;
    if (s == 'waiting') return AppColors.secondary;
    if (s == 'cancelled') return AppColors.textHint;
    if (s == 'billed') return AppColors.success;
    return AppColors.secondary;
  }

  String _getServerStatusText(String status) {
    if (status == 'Received') return 'Unbilled';
    return status;
  }

  void _onCopy(BuildContext context) {
    final parentMessenger = ScaffoldMessenger.of(context);
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => AddWorkOrderPage(copyFrom: widget.workOrder),
        fullscreenDialog: true,
      ),
    )
        .then((result) async {
      if (result == 'refresh') {
        final storage = ref.read(storageServiceProvider);
        final techId = storage.getFromSession('logged_in_emp_id').toString();
        await ref
            .read(technicianWorkOrderProvider)
            .loadTechnicianWorkOrders(techId);
        if (mounted) {
          parentMessenger.showSnackBar(
            SnackBar(
              content: Text('Copied Successfully'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    });
  }

  void _onStart(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            HCProcessPage(workOrderId: widget.workOrder.docId),
      ),
    );
  }

  void _onCancel(BuildContext context) {
    final parentMessenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (context) => CancelWorkOrderDialog(workOrder: widget.workOrder),
    ).then((result) async {
      if (result == true) {
        final storage = ref.read(storageServiceProvider);
        final techId = storage.getFromSession('logged_in_emp_id').toString();
        await ref
            .read(technicianWorkOrderProvider)
            .loadTechnicianWorkOrders(techId);
        parentMessenger.showSnackBar(
          SnackBar(
            content: Text('Cancelled Successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    });
  }
}
