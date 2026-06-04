import 'dart:async';
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
import '../providers/manager_work_order_provider.dart';

class ManagerMobileView extends ConsumerStatefulWidget {
  const ManagerMobileView({super.key});

  @override
  ConsumerState<ManagerMobileView> createState() => _ManagerMobileViewState();
}

class _ManagerMobileViewState extends ConsumerState<ManagerMobileView> {
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = ref.watch(managerFilteredWorkOrdersPod);
    final currentFilter = ref.watch(managerStatusFilterPod);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search patients...',
              prefixIcon: Icon(Icons.search, color: isDark ? AppColors.darkTextSecondary : AppColors.textHint),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: AppRadius.mdAll,
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (v) {
              _searchDebounce?.cancel();
              _searchDebounce = Timer(const Duration(milliseconds: 300), () {
                ref.read(managerSearchPod.notifier).state = v;
              });
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(context, 'All', 'all', currentFilter),
                const SizedBox(width: 6),
                _buildFilterChip(context, 'New', 'new', currentFilter),
                const SizedBox(width: 6),
                _buildFilterChip(context, 'In Progress', 'in_progress', currentFilter),
                const SizedBox(width: 6),
                _buildFilterChip(context, 'Finished', 'finished', currentFilter),
                const SizedBox(width: 6),
                _buildFilterChip(context, 'Cancelled', 'cancelled', currentFilter),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Text(
                '${filtered.length} work order(s)',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              _buildSortDropdown(context),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyState(context)
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    return RepaintBoundary(
                      child: _MobileWorkOrderCard(
                        workOrder: filtered[index],
                        index: index + 1,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(BuildContext context, String label, String value, String current) {
    final isSelected = current == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => ref.read(managerStatusFilterPod.notifier).state = value,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : Theme.of(context).colorScheme.surface,
          borderRadius: AppRadius.lgAll,
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.darkBorder : AppColors.tableBorder),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildSortDropdown(BuildContext context) {
    final sortCol = ref.watch(managerSortColumnPod);
    final sortAsc = ref.watch(managerSortAscendingPod);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.sort, size: 14, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
        const SizedBox(width: 4),
        DropdownButton<String>(
          value: sortCol,
          isDense: true,
          underline: const SizedBox.shrink(),
          style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
          dropdownColor: colorScheme.surface,
          items: const [
            DropdownMenuItem(value: 'date', child: Text('Date & Time')),
            DropdownMenuItem(value: 'time', child: Text('Time')),
            DropdownMenuItem(value: 'name', child: Text('Patient Name')),
            DropdownMenuItem(value: 'status', child: Text('Status')),
            DropdownMenuItem(
                value: 'server_status', child: Text('Server Status')),
            DropdownMenuItem(value: 'assigned_to', child: Text('Assigned To')),
          ],
          onChanged: (v) {
            if (v != null) {
              ref.read(managerSortColumnPod.notifier).state = v;
            }
          },
        ),
        IconButton(
          icon: Icon(
            sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
            size: 14,
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
          onPressed: () =>
              ref.read(managerSortAscendingPod.notifier).state = !sortAsc,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          tooltip: sortAsc ? 'Ascending' : 'Descending',
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.assignment_outlined,
              size: 48,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textHint,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Work Orders Found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filter',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textHint,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.mdAll,
        side: BorderSide(
          color: _isExpanded
              ? AppColors.primary
              : (isDark ? AppColors.darkBorder : AppColors.divider),
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
                          color: isDark
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : AppColors.primaryLight,
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
                            Row(
                              children: [
                                Text(
                                  '${wo.gender} • ${wo.age} • ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                  ),
                                ),
                                Flexible(
                                  child: CopyableText(
                                    wo.mobile,
                                    isPhoneNumber: true,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
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
                          color: isDark ? AppColors.darkSurfaceAlt : AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.access_time,
                                size: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              wo.visitTime,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
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
                        child: CopyableText(
                          wo.assignedTo.isNotEmpty
                              ? wo.assignedTo
                              : 'Unassigned',
                          style: TextStyle(
                            fontSize: 12,
                            color: wo.assignedTo.isNotEmpty
                                ? colorScheme.onSurface
                                : (isDark ? AppColors.darkTextSecondary : AppColors.textHint),
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
                  Divider(
                    height: 1,
                    color: isDark ? AppColors.darkBorder : AppColors.divider,
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: ManagerActions(workOrder: wo),
                  ),
                  Divider(
                    height: 1,
                    color: isDark ? AppColors.darkBorder : AppColors.divider,
                  ),
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
