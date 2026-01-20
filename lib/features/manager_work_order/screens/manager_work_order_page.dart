import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import 'package:anderson_crm_flutter/providers/notificationCenter_provider.dart';
import 'package:anderson_crm_flutter/providers/com_center_provider.dart';
import 'package:anderson_crm_flutter/database/sms_template.dart';
import 'package:anderson_crm_flutter/config/settings.dart';
import 'package:anderson_crm_flutter/components/add_work_order.dart';
import 'package:anderson_crm_flutter/components/assign_technicians.dart';
import 'package:anderson_crm_flutter/components/canceled_work_order_page.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/features/price_list/screens/manager_price_view_page.dart';
import 'package:anderson_crm_flutter/features/tech_engagement/screens/tech_engagement_page.dart';
import 'package:anderson_crm_flutter/features/core/util.dart';

import '../../theme/theme.dart';

import 'package:anderson_crm_flutter/features/core/widgets/common/common_widgets.dart';

import '../providers/manager_work_order_provider.dart';
import '../widgets/manager_actions.dart';
import '../widgets/manager_expanded_content.dart';
import '../widgets/manager_mobile_view.dart';

final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

class ManagerWorkOrderPage extends ConsumerStatefulWidget {
  const ManagerWorkOrderPage({Key? key}) : super(key: key);

  @override
  ConsumerState<ManagerWorkOrderPage> createState() =>
      _ManagerWorkOrderPageState();
}

class _ManagerWorkOrderPageState extends ConsumerState<ManagerWorkOrderPage> {
  @override
  void initState() {
    super.initState();

    // Waits for first frame then defers heavy work for navigation animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!mounted) return;
        final provider = ref.read(managerWorkOrderProvider);
        if (provider.isInitializing) {
          provider.initialize();
        }
        final today = ref.read(managerTodayPod);
        provider.loadWorkOrdersByDate(today);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(managerWorkOrderProvider);
    final selected = ref.watch(managerSelectedDatePod);
    final today = ref.read(managerTodayPod);

    final dateOffsets = [3, 2, 1, 0, -1, -2, -3, -4, -5];
    final dateChips = dateOffsets.asMap().entries.map((entry) {
      final idx = entry.key;
      final off = entry.value;
      final date = today.add(Duration(days: off));
      String label;
      bool isFuturePlus = idx == 0; // First chip is "6+ Days"

      if (isFuturePlus) {
        label = '6+ Days\n${DateFormat('MM-dd').format(date)}';
      } else if (off == 2) {
        label = _dateFormat.format(date);
      } else if (off == 1) {
        label = 'NEXTDAY\n${DateFormat('MM-dd').format(date)}';
      } else if (off == 0) {
        label = 'TODAY\n${DateFormat('MM-dd').format(date)}';
      } else if (off == -1) {
        label = 'YESTERDAY\n${DateFormat('MM-dd').format(date)}';
      } else {
        label = _dateFormat.format(date);
      }
      return _DateChipProps(date, label, isFuturePlus: isFuturePlus);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.backgroundSmoke,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 4,
        surfaceTintColor: AppColors.surface,
        title: Padding(
          padding: EdgeInsets.only(left: AppSpacing.sm),
          child: Row(
            children: [
              Container(
                padding: AppPadding.badge,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: AppRadius.lgAll,
                ),
                child: Text(
                  'Work Orders',
                  style: AppTextStyles.badge.copyWith(fontSize: 16),
                ),
              ),
              SizedBox(width: AppSpacing.lg),
              if (provider.isConnected)
                Tooltip(
                    message: 'Connected',
                    child: Icon(Icons.cloud_done,
                        color: AppColors.success, size: AppSizes.iconSm))
              else
                Tooltip(
                    message: 'Offline',
                    child: Icon(Icons.cloud_off,
                        color: AppColors.primary, size: AppSizes.iconSm)),
              if (provider.isSyncing)
                Padding(
                    padding: EdgeInsets.only(left: AppSpacing.sm),
                    child: SizedBox(
                        width: AppSizes.iconXs,
                        height: AppSizes.iconXs,
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
                    builder: (context) => const TechEngagementPage())),
          ),
          IconButton(
            tooltip: 'Add',
            icon: const Icon(Icons.add_circle_outline, color: Colors.black87),
            onPressed: () => _openAddEditPage(context, ref),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            height: 60,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(color: AppColors.divider, width: 0.5),
              ),
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding:
                  EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 8),
              itemCount: dateChips.length,
              itemBuilder: (_, idx) {
                final chip = dateChips[idx];
                final isSel = chip.date.year == selected.year &&
                    chip.date.month == selected.month &&
                    chip.date.day == selected.day;
                final isToday = chip.date.year == today.year &&
                    chip.date.month == today.month &&
                    chip.date.day == today.day;

                return Padding(
                  padding: EdgeInsets.only(right: AppSpacing.sm),
                  child: _ModernDateChip(
                    date: chip.date,
                    label: chip.label,
                    isSelected: isSel,
                    isToday: isToday,
                    onTap: () async {
                      ref.read(managerSelectedDatePod.notifier).state =
                          chip.date;
                      await provider.loadWorkOrdersByDate(chip.date,
                          fromDateOnwards: chip.isFuturePlus);
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
      body: _buildBody(context, provider),
    );
  }

  Widget _buildBody(BuildContext context, ManagerWorkOrderProvider provider) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    if (provider.isInitializing ||
        (provider.isLoading && provider.workOrders.isEmpty)) {
      return Padding(
        padding: isMobile
            ? EdgeInsets.zero
            : EdgeInsets.fromLTRB(
                AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl, 0),
        child: _buildSkeletonLoading(),
      );
    }
    if (provider.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: AppSizes.iconLg + 16, color: AppColors.error),
            Text('Error: ${provider.errorMessage}'),
            ElevatedButton(
              onPressed: () async {
                final today = ref.read(managerTodayPod);
                await provider.loadWorkOrdersByDate(today);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Mobile view with cards
    if (isMobile) {
      return ManagerMobileView(
        workOrders: ref.watch(managerFilteredWorkOrdersPod),
        searchQuery: ref.watch(managerSearchPod),
        onSearchChanged: (value) =>
            ref.read(managerSearchPod.notifier).state = value,
      );
    }

    // Desktop view with table
    return Padding(
      padding:
          EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl, 0),
      child: VirtualManagerTable(rows: ref.watch(managerFilteredWorkOrdersPod)),
    );
  }

  Widget _buildSkeletonLoading() {
    return Column(
      children: [
        Container(
          margin: EdgeInsets.only(bottom: AppSpacing.md),
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.tableBorder,
            borderRadius: AppRadius.mdAll,
          ),
        ),
        Expanded(
          child: Card(
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
                        8,
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
                              8,
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

  void _openAddEditPage(BuildContext context, WidgetRef ref) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
          builder: (context) => const AddWorkOrderPageMobile(),
          fullscreenDialog: true),
    )
        .then((value) async {
      if (value == 'refresh') {
        final selectedDate = ref.read(managerSelectedDatePod);
        await ref
            .read(managerWorkOrderProvider)
            .loadWorkOrdersByDate(selectedDate);
      }
    });
  }
}

class VirtualManagerTable extends ConsumerWidget {
  final List<WorkOrder> rows;
  const VirtualManagerTable({super.key, required this.rows});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sortCol = ref.watch(managerSortColumnPod);
    final sortAsc = ref.watch(managerSortAscendingPod);

    // Use passed rows directly
    final filtered = rows;

    debugPrint(
        'VirtualManagerTable building. Filtered count: ${filtered.length}');

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
          onChanged: (v) => ref.read(managerSearchPod.notifier).state = v,
        ),
        Expanded(
          child: Card(
            elevation: AppSizes.cardElevation,
            color: AppColors.surface,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8)),
                    border: Border(
                        bottom:
                            BorderSide(color: AppColors.tableBorder, width: 1)),
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
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text('No Data Available due to filtering',
                              style: TextStyle(color: AppColors.textSecondary)))
                      : ListView.separated(
                          itemCount: filtered.length,
                          cacheExtent:
                              500, // Pre-render items for smooth scroll
                          addAutomaticKeepAlives: false,
                          addRepaintBoundaries: true,
                          separatorBuilder: (ctx, i) =>
                              Divider(height: 1, color: AppColors.divider),
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
    extends ConsumerState<_ManagerExpandableRowConsumer>
    with AutomaticKeepAliveClientMixin {
  bool _isExpanded = false;

  @override
  bool get wantKeepAlive => _isExpanded; // Only keep alive if expanded

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
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
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
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
      final provider = ref.read(managerWorkOrderProvider);
      final storage = ref.read(storageServiceProvider);
      final managerName = storage.getFromSession("logged_in_emp_name");

      // Check if this is a re-assignment (Vue: doc.prev_assigned_to)
      final isReassignment = workOrder.assignedTo.isNotEmpty;

      final updatedOrder = workOrder.copyWith(
        assignedId: int.tryParse(techId) ?? 0,
        assignedTo: techName,
        status: 'assigned',
        lastUpdatedBy: managerName,
        lastUpdatedAt: DateTime.now(),
      );

      final now = DateTime.now();
      final formattedDate = DateFormat('MMMM dd, hh:mm a').format(now);
      final assignmentLog = isReassignment
          ? "$formattedDate | $managerName | Re-assigned To $techName (prev: ${workOrder.assignedTo})"
          : "$formattedDate | $managerName | Assigned To $techName";
      final existingTimeline = List<String>.from(workOrder.timeLine);
      existingTimeline.add(assignmentLog);

      final customDoc = updatedOrder.buildDoc();
      customDoc['time_line'] = existingTimeline;

      // Track previous assignment for re-assignment SMS (Vue: prev_assigned_to/id)
      if (isReassignment) {
        customDoc['prev_assigned_to'] = workOrder.assignedTo;
        customDoc['prev_assigned_id'] = workOrder.assignedId;
      }

      await provider.updateWorkOrder(updatedOrder, customDoc: customDoc);

      // Send in-app notification (mirrors Vue's send_notification)
      debugPrint("🔔 About to send in-app notification...");
      await _sendInAppNotification(workOrder, techId, techName);

      if (context.mounted) {
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

  /// Send in-app notification to the assigned technician (mirrors Vue's send_notification)
  /// Uses NotificationCenter which properly resolves DB name from doc_dbs session
  Future<void> _sendInAppNotification(
      WorkOrder workOrder, String techId, String techName) async {
    try {
      final notificationCenter = ref.read(notificationCenterServiceProvider);
      final storage = ref.read(storageServiceProvider);

      // Build notification message matching Vue format
      final appointmentDate =
          DateFormat('dd-MM-yyyy').format(workOrder.visitDate);
      final msgHeader =
          "Collection on $appointmentDate ${workOrder.visitTime} assigned.";
      final msgBody = "Home collection for ${workOrder.patientName}"
          "(${workOrder.age}/${workOrder.gender}) "
          "address:${workOrder.address} mobile:${workOrder.mobile} pincode:${workOrder.pincode}"
          " ${workOrder.freeText}";

      debugPrint(
          "📤 Sending notification to techId=$techId, techName=$techName");

      // Build notification payload matching Vue format
      final notification = {
        '_id': 'notifications:${Util.getDateForId()}:${Util.uuidv4()}',
        'from_id': storage.getFromSession('logged_in_emp_id'),
        'from_name': storage.getFromSession('logged_in_emp_name'),
        'to_id': techId,
        'to_name': techName,
        'msg_header': msgHeader,
        'msg_body': msgBody,
        'msg_attachment': {},
        'status': 'New',
        'msg_time': Util.getTodayWithTime(),
        'updated_at': Util.getTimeStamp(),
      };

      final result = await notificationCenter.sendNotification(notification);

      if (result == "OK") {
        debugPrint(" In-app notification sent to $techName");
      } else {
        debugPrint(" Failed to send in-app notification: $result");
      }
    } catch (e) {
      debugPrint(" Error sending in-app notification: $e");
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

                  // Skip in development mode
                  // if (Settings.development) {
                  //   debugPrint('⏭️ Skipping SMS/WhatsApp (development mode)');
                  //   messenger.showSnackBar(SnackBar(
                  //       content: Text('Dev mode: Messages skipped'),
                  //       backgroundColor: AppColors.primary));
                  //   return;
                  // }

                  // Send actual messages (mirrors Vue's ok_msg_dialog)
                  await _sendAssignmentMessages(
                    workOrder: workOrder,
                    techId: techId,
                    techName: techName,
                    sendSms: sendSms,
                    sendWhatsApp: sendWhatsApp,
                    sendEmail: sendEmail,
                    isReassignment: isReassignment,
                    messenger: messenger,
                  );
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _sendAssignmentMessages({
    required WorkOrder workOrder,
    required String techId,
    required String techName,
    required bool sendSms,
    required bool sendWhatsApp,
    required bool sendEmail,
    required bool isReassignment,
    required ScaffoldMessengerState messenger,
  }) async {
    try {
      final storage = ref.read(storageServiceProvider);
      final comCenter = ref.read(comCenterProvider);

      // Get technician mobile (TODO: fetch from PostgresDB if needed)
      final techMobile = ""; // Will be empty for now

      final idPart = Util.getRandomString(5);
      final msgUrl = '${Settings.msgUrl}$idPart';

      // Build base message object
      final baseMessage = {
        'center_id': storage.getFromSession('logged_in_tenant_id'),
        'center_name': storage.getFromSession('logged_in_tenant_name'),
        'department_id': storage.getFromSession('department_id'),
        'department_name': storage.getFromSession('department_name'),
        'role_id': storage.getFromSession('role_id'),
        'role_name': storage.getFromSession('role_name'),
        'emp_id': storage.getFromSession('logged_in_emp_id'),
        'emp_name': storage.getFromSession('logged_in_emp_name'),
        'recipient_mobile': workOrder.mobile,
        'recipient_name': workOrder.patientName,
        'status': '0',
        'msg_time': Util.getTodayWithTime(),
        'updated_at': Util.getTimeStamp(),
      };

      // Send SMS
      if (sendSms) {
        String smsMsg;
        if (isReassignment) {
          // Tech change SMS template
          smsMsg = SmsTemplate.homeCollectionTechChange(
              techName, techMobile, msgUrl);
        } else {
          // New assignment SMS template
          final appTime =
              "${DateFormat('dd-MM-yyyy').format(workOrder.visitDate)} ${workOrder.visitTime}";
          smsMsg = SmsTemplate.sampleCollection(
              workOrder.patientName, techName, appTime, techMobile, msgUrl);
        }

        final smsMessage = Map<String, dynamic>.from(baseMessage);
        smsMessage['_id'] = 'sms_center:$idPart:${Util.uuidv4()}';
        smsMessage['message'] = smsMsg;

        debugPrint('📤 Sending assignment SMS to ${workOrder.mobile}');
        final result = await comCenter.sendMsg(smsMessage);
        if (result == 'OK') {
          debugPrint(' SMS sent successfully');
        } else {
          debugPrint(' SMS failed: $result');
        }
      }

      // Send WhatsApp
      if (sendWhatsApp) {
        List<String> whatsappMsg;
        String template;

        if (isReassignment) {
          whatsappMsg = [techName, techMobile, msgUrl];
          template = 'Technician_change_for_hc';
        } else {
          final appTime =
              "${DateFormat('dd-MM-yyyy').format(workOrder.visitDate)} ${workOrder.visitTime}";
          whatsappMsg = [
            workOrder.patientName,
            techName,
            appTime,
            techMobile,
            msgUrl
          ];
          template = 'hc_technician_allocation3';
        }

        final waMessage = Map<String, dynamic>.from(baseMessage);
        waMessage['_id'] = 'whatsapp_center:$idPart:${Util.uuidv4()}';
        waMessage['message'] = whatsappMsg;
        waMessage['template'] = template;

        debugPrint('📤 Sending assignment WhatsApp to ${workOrder.mobile}');
        final result = await comCenter.sendMsg(waMessage);
        if (result == 'OK') {
          debugPrint(' WhatsApp sent successfully');
        } else {
          debugPrint(' WhatsApp failed: $result');
        }
      }

      // Send Email (placeholder - uses same pattern)
      if (sendEmail) {
        final emailMessage = Map<String, dynamic>.from(baseMessage);
        emailMessage['_id'] = 'email_center:$idPart:${Util.uuidv4()}';

        debugPrint('📤 Sending assignment Email to ${workOrder.email}');
        final result = await comCenter.sendMsg(emailMessage);
        if (result == 'OK') {
          debugPrint(' Email sent successfully');
        } else {
          debugPrint(' Email failed: $result');
        }
      }

      messenger.showSnackBar(SnackBar(
          content: Text('Notifications sent'),
          backgroundColor: AppColors.success));
    } catch (e) {
      debugPrint(' Error sending assignment messages: $e');
      messenger.showSnackBar(SnackBar(
          content: Text('Error sending notifications'),
          backgroundColor: AppColors.error));
    }
  }
}

class _DateChipProps {
  final DateTime date;
  final String label;
  final bool isFuturePlus;
  _DateChipProps(this.date, this.label, {this.isFuturePlus = false});
}

/// Modern date chip with gradient styling for selected state
class _ModernDateChip extends StatelessWidget {
  final DateTime date;
  final String label;
  final bool isSelected;
  final bool isToday;
  final VoidCallback onTap;

  const _ModernDateChip({
    required this.date,
    required this.label,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Parse the label to get display text
    final lines = label.split('\n');
    final hasTitle = lines.length > 1;
    final title = hasTitle ? lines[0] : null;
    final dateText = hasTitle ? lines[1] : lines[0];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected
                ? null
                : (isToday ? AppColors.primaryLight : AppColors.surfaceAlt),
            borderRadius: BorderRadius.circular(12),
            border: isToday && !isSelected
                ? Border.all(color: AppColors.primary, width: 1.5)
                : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != null)
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.primary,
                    letterSpacing: 0.3,
                    height: 1.2,
                  ),
                ),
              Text(
                dateText,
                style: TextStyle(
                  fontSize: hasTitle ? 12 : 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
