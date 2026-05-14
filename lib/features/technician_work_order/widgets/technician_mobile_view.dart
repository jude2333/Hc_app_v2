import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/features/add_work_order/add_work_order_page.dart';
import 'package:anderson_crm_flutter/components/cancel_work_order_dialog.dart';
import 'package:anderson_crm_flutter/components/edit_work_order_dialog.dart';
import 'package:anderson_crm_flutter/features/hc_process/screens/hc_process_page.dart';
import 'add_tests_post_completion_page.dart';
import '../../theme/theme.dart';
import '../../core/widgets/common/common_widgets.dart';
import '../providers/technician_work_order_provider.dart';
import 'technician_expanded_content.dart';

class TechnicianMobileView extends ConsumerWidget {
  final List<WorkOrder> workOrders;

  const TechnicianMobileView({
    super.key,
    required this.workOrders,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = ref.watch(techSearchPod);

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
            onChanged: (v) => ref.read(techSearchPod.notifier).state = v,
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
                    return RepaintBoundary(
                      child: _TechnicianMobileCard(workOrder: filtered[index]),
                    );
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

  bool _checkEditableStatus() {
    final status = widget.workOrder.status.toLowerCase();
    return status != 'na' && status != 'finished' && status != 'cancelled';
  }

  /// Can add tests if finished within the last 24 hours.
  bool _canAddTests() {
    final status = widget.workOrder.status.toLowerCase();
    if (status != 'finished') return false;
    final elapsed = DateTime.now().difference(widget.workOrder.lastUpdatedAt);
    return elapsed.inHours < 24;
  }

  @override
  Widget build(BuildContext context) {
    final wo = widget.workOrder;
    final canEdit = _checkEditableStatus();
    final showAddTests = _canAddTests();

    return Card(
      margin: EdgeInsets.only(bottom: AppSpacing.sm),
      elevation: 2,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                          if (canEdit)
                            Padding(
                              padding: EdgeInsets.only(left: AppSpacing.xs),
                              child: InkWell(
                                onTap: () => _onEdit(context),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(Icons.edit,
                                      size: 14, color: AppColors.success),
                                ),
                              ),
                            ),
                        ],
                      ),
                      _buildBadges(wo),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildInfoTable(wo),
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
                if (showAddTests) ...[
                  SizedBox(width: AppSpacing.xs),
                  _buildActionChip('+ Tests', () => _onAddTests(context),
                      color: AppColors.primary),
                ],
                if (canEdit) ...[
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
                  icon: Icon(Icons.chevron_right, color: AppColors.textHint),
                  onPressed: _showViewMoreDialog,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'More Info',
                ),
                IconButton(
                  icon: Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.primary,
                  ),
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                  visualDensity: VisualDensity.compact,
                  tooltip: _isExpanded ? 'Collapse' : 'Expand',
                ),
              ],
            ),
          ),
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
    final testItems = wo.parsedDoc['test_items'];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(3),
        },
        children: [
          _tableRow('Mobile', wo.mobile),
          if (wo.alternateMobile.isNotEmpty)
            _tableRow('Alt. Mobile', wo.alternateMobile),
          _tableRow('App. Time', '${wo.formattedVisitDate} ${wo.visitTime}'),
          _tableRow('My Status', '',
              statusWidget: StatusChip(status: wo.status)),
          if (!isCancelled) ...[
            if (wo.clientCode.isNotEmpty)
              _tableRow('Client Code', wo.clientCode),
            if (wo.doctorCode.isNotEmpty)
              _tableRow('Doctor Code', wo.doctorCode),
            _tableRow('Test Items', testItems != null ? 'View' : 'Nil',
                isViewable: testItems != null,
                onTap: testItems != null ? () => _viewTests(testItems) : null),
            _tableRow('GPay', _getGPayDisplay(wo)),
            _tableRow(
                'Prescription',
                wo.prescriptionPath.isNotEmpty
                    ? '${_getFileName(wo.prescriptionPath)} ⤵'
                    : 'Nil',
                isViewable: wo.prescriptionPath.isNotEmpty),
          ],
        ],
      ),
    );
  }

  TableRow _tableRow(String label, String value,
      {Widget? statusWidget, bool isViewable = false, VoidCallback? onTap}) {
    final valueWidget = statusWidget ??
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            color: isViewable ? AppColors.primary : AppColors.textPrimary,
            fontWeight: isViewable ? FontWeight.w500 : FontWeight.normal,
          ),
        );

    return TableRow(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Text(label,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ),
        Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: onTap != null
              ? GestureDetector(
                  onTap: onTap,
                  child: valueWidget,
                )
              : valueWidget,
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

  Widget _buildBadges(WorkOrder wo) {
    List<String> badges = [];
    if (wo.urgent) badges.add('Urgent');
    if (wo.vip) badges.add('VIP');
    if (wo.credit == 1) badges.add('Credit');
    if (wo.credit == 2) badges.add('Trial');
    if (wo.b2bClientId != null && wo.b2bClientId! > 0) badges.add('B2B');
    if (wo.cghsClient) badges.add('CGHS');

    if (badges.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: AppSpacing.xs),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: badges.map((badge) {
          final isCghs = badge == 'CGHS';
          final color = isCghs ? Colors.blue : AppColors.error;
          return Container(
            padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppRadius.smAll,
            ),
            child: Text(
              badge,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }).toList(),
      ),
    );
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
      if (result == 'refresh' && mounted) {
        parentMessenger.showSnackBar(
          SnackBar(
            content: Text('Copied Successfully'),
            backgroundColor: AppColors.success,
          ),
        );
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

  void _onAddTests(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddTestsPostCompletionPage(workOrder: widget.workOrder),
        fullscreenDialog: true,
      ),
    );
  }

  void _onCancel(BuildContext context) {
    final parentMessenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (context) => CancelWorkOrderDialog(workOrder: widget.workOrder),
    ).then((result) async {
      if (result == true && mounted) {
        parentMessenger.showSnackBar(
          SnackBar(
            content: Text('Cancelled Successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    });
  }

  void _onEdit(BuildContext context) {
    final parentMessenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (context) => EditWorkOrderDialog(workOrder: widget.workOrder),
    ).then((result) async {
      if (result == true && mounted) {
        parentMessenger.showSnackBar(
          SnackBar(
            content: Text('Updated Successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    });
  }

  void _viewTests(dynamic testItems) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Test Items',
            style: TextStyle(
                color: AppColors.primary, fontWeight: FontWeight.w600)),
        content: SingleChildScrollView(
          child: Text(
            testItems.toString(),
            style: TextStyle(fontSize: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showViewMoreDialog() {
    final wo = widget.workOrder;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('More Info',
            style: TextStyle(
                color: AppColors.primary, fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _viewMoreRow('Address', wo.address.isEmpty ? 'N/A' : wo.address),
            _viewMoreRow('Pincode', wo.pincode.isEmpty ? 'N/A' : wo.pincode),
            _viewMoreRow('Mobile', wo.mobile.isEmpty ? 'N/A' : wo.mobile),
            _viewMoreRow(
                'Additional Info', wo.freeText.isEmpty ? 'N/A' : wo.freeText),
            _viewMoreRow(
                'Ref. By', wo.doctorName.isEmpty ? 'N/A' : wo.doctorName),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _viewMoreRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
          children: [
            TextSpan(
                text: '$label : ',
                style: TextStyle(fontWeight: FontWeight.w500)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
