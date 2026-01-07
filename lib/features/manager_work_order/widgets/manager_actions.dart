import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/providers/work_order_provider.dart';
import 'package:anderson_crm_flutter/powersync/screens/add_work_order.dart';
import '../screens/manager_work_order_page.dart';
import '../../theme/theme.dart';

class ManagerActions extends ConsumerWidget {
  final WorkOrder workOrder;

  const ManagerActions({super.key, required this.workOrder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finished = ['Finished', 'cancelled'].contains(workOrder.status);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.content_copy,
              size: AppSizes.iconSm - 2, color: AppColors.textHint),
          onPressed: () => _copyWorkOrder(context, ref),
          tooltip: 'Copy',
        ),
        if (!finished) ...[
          IconButton(
            icon: Icon(Icons.edit,
                size: AppSizes.iconSm - 2, color: AppColors.secondary),
            onPressed: () => _editWorkOrder(context, ref),
            tooltip: 'Edit',
          ),
          IconButton(
            icon: Icon(Icons.delete,
                size: AppSizes.iconSm - 2, color: AppColors.error),
            onPressed: () => _confirmDelete(context, ref),
            tooltip: 'Delete',
          ),
        ],
      ],
    );
  }

  void _copyWorkOrder(BuildContext context, WidgetRef ref) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddWorkOrderPageMobile(copyFrom: workOrder),
        fullscreenDialog: true,
      ),
    ).then((res) async {
      if (res == 'refresh') _refresh(context, ref, 'Copied');
    });
  }

  void _editWorkOrder(BuildContext context, WidgetRef ref) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddWorkOrderPageMobile(existingWorkOrder: workOrder),
        fullscreenDialog: true,
      ),
    ).then((res) async {
      if (res == 'refresh') _refresh(context, ref, 'Updated');
    });
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete?'),
        content: Text('Delete ${workOrder.patientName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await ref
                  .read(workOrderProvider)
                  .softDeleteWorkOrder(int.parse(workOrder.id), 'Manager');
              if (success) {
                final date = ref.read(selectedDatePod);
                await ref.read(workOrderProvider).loadWorkOrdersByDate(date);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Deleted'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            child: Text('Yes', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _refresh(BuildContext context, WidgetRef ref, String msg) async {
    final date = ref.read(selectedDatePod);
    await ref.read(workOrderProvider).loadWorkOrdersByDate(date);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$msg Successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }
}
