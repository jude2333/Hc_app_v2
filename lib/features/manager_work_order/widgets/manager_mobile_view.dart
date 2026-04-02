import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/features/theme/theme.dart';
import 'package:anderson_crm_flutter/features/core/widgets/common/common_widgets.dart';
import 'package:anderson_crm_flutter/components/assign_technicians.dart';
import '../widgets/manager_expanded_content.dart';
import '../widgets/manager_actions.dart';
import '../controllers/manager_assignment_controller.dart';
import 'package:anderson_crm_flutter/features/theme/app_spacing.dart';

class ManagerMobileView extends ConsumerWidget {
  final List<WorkOrder> workOrders;
  final String searchQuery;
  final Function(String) onSearchChanged;

  const ManagerMobileView({
    super.key,
    required this.workOrders,
    required this.searchQuery,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtered = workOrders;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search patients...',
              prefixIcon: Icon(Icons.search, color: AppColors.textHint),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: AppRadius.mdAll,
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: onSearchChanged,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Text(
                '${filtered.length} work orders',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    return _MobileWorkOrderCard(
                      workOrder: filtered[index],
                      index: index + 1,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
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
            'No Work Orders Found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or date',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileWorkOrderCard extends ConsumerStatefulWidget {
  final WorkOrder workOrder;
  final int index;

  const _MobileWorkOrderCard({
    required this.workOrder,
    required this.index,
  });

  @override
  ConsumerState<_MobileWorkOrderCard> createState() =>
      _MobileWorkOrderCardState();
}

class _MobileWorkOrderCardState extends ConsumerState<_MobileWorkOrderCard> {
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
          color: _isExpanded ? AppColors.primary : AppColors.divider,
          width: _isExpanded ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: AppRadius.mdAll,
                        ),
                        child: Center(
                          child: Text(
                            '${widget.index}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            NameWithBadges(
                              workOrder: wo,
                              layout: BadgeLayout.row,
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
                  Row(
                    children: [
                      StatusChip(
                        status: wo.status,
                        onTap: () => _showAssignDialog(context, wo),
                      ),
                      const SizedBox(width: 8),
                      ServerChip(status: wo.serverStatus),
                      const Spacer(),
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
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.person_outline,
                          size: 14, color: AppColors.textHint),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          wo.assignedTo.isNotEmpty
                              ? wo.assignedTo
                              : 'Unassigned',
                          style: TextStyle(
                            fontSize: 12,
                            color: wo.assignedTo.isNotEmpty
                                ? AppColors.textPrimary
                                : AppColors.textHint,
                            fontStyle: wo.assignedTo.isEmpty
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            RepaintBoundary(
              child: Column(
                children: [
                  Divider(height: 1, color: AppColors.divider),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: ManagerActions(workOrder: wo),
                  ),
                  Divider(height: 1, color: AppColors.divider),
                  ManagerExpandedContent(workOrder: wo),
                ],
              ),
            ),
        ],
      ),
    );
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
