import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/features/technician_work_order/utils/technician_actions_helper.dart';
import '../../theme/theme.dart';

/// Technician-specific action buttons for work order rows.
/// Includes: Copy, Start HC Process, Edit, Cancel actions.
class TechnicianActions extends ConsumerWidget {
  final WorkOrder workOrder;

  const TechnicianActions({super.key, required this.workOrder});

  bool _checkStatus() {
    String status = workOrder.status.toLowerCase();
    return status != 'na' && status != 'finished' && status != 'cancelled';
  }

  /// Can add tests if finished within the last 24 hours.
  bool _canAddTests() {
    if (workOrder.status.toLowerCase() != 'finished') return false;
    final elapsed = DateTime.now().difference(workOrder.lastUpdatedAt);
    return elapsed.inHours < 24;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showActions = _checkStatus();
    final canAddTests = _canAddTests();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.content_copy,
              size: AppSizes.iconSm - 2, color: AppColors.textHint),
          onPressed: () => TechnicianActionsHelper.copyWorkOrder(context, workOrder),
          tooltip: 'Copy',
        ),
        if (canAddTests)
          IconButton(
            icon: Icon(Icons.post_add,
                size: AppSizes.iconSm, color: AppColors.primary),
            onPressed: () => TechnicianActionsHelper.addTestsPostCompletion(context, workOrder),
            tooltip: 'Add Tests',
          ),
        if (showActions) ...[
          IconButton(
            icon: Icon(Icons.play_circle_outline,
                size: AppSizes.iconSm, color: AppColors.success),
            onPressed: () => TechnicianActionsHelper.startHCProcess(context, ref, workOrder),
            tooltip: 'Start',
          ),
          IconButton(
            icon: Icon(Icons.edit,
                size: AppSizes.iconSm - 2, color: AppColors.secondary),
            onPressed: () => TechnicianActionsHelper.editWorkOrder(context, workOrder),
            tooltip: 'Edit',
          ),
          IconButton(
            icon: Icon(Icons.close,
                size: AppSizes.iconSm - 2, color: AppColors.error),
            onPressed: () => TechnicianActionsHelper.cancelWorkOrder(context, workOrder),
            tooltip: 'Cancel',
          ),
        ],
      ],
    );
  }
}
