import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import 'package:anderson_crm_flutter/powersync/screens/add_work_order.dart';
import 'package:anderson_crm_flutter/powersync/screens/edit_work_order_dialog.dart';
import 'package:anderson_crm_flutter/powersync/screens/cancel_work_order_dialog.dart';
import 'package:anderson_crm_flutter/powersync/screens/hc_process_page.dart';
import '../../theme/theme.dart';
import '../providers/technician_work_order_provider.dart';

class TechnicianActions extends ConsumerWidget {
  final WorkOrder workOrder;

  const TechnicianActions({super.key, required this.workOrder});

  bool _checkStatus() {
    String status = workOrder.status.toLowerCase();
    return status != 'na' && status != 'finished' && status != 'cancelled';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showActions = _checkStatus();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.content_copy,
              size: AppSizes.iconSm - 2, color: AppColors.textHint),
          onPressed: () => _copyWorkOrder(context, ref),
          tooltip: 'Copy',
        ),
        if (showActions) ...[
          IconButton(
            icon: Icon(Icons.play_circle_outline,
                size: AppSizes.iconSm, color: AppColors.success),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      HCProcessPage3(workOrderId: workOrder.docId),
                ),
              );
            },
            tooltip: 'Start',
          ),
          IconButton(
            icon: Icon(Icons.edit,
                size: AppSizes.iconSm - 2, color: AppColors.secondary),
            onPressed: () => _editWorkOrder(context, ref),
            tooltip: 'Edit',
          ),
          IconButton(
            icon: Icon(Icons.close,
                size: AppSizes.iconSm - 2, color: AppColors.error),
            onPressed: () => _cancelWorkOrder(context, ref),
            tooltip: 'Cancel',
          ),
        ],
      ],
    );
  }

  void _copyWorkOrder(BuildContext context, WidgetRef ref) {
    final parentMessenger = ScaffoldMessenger.of(context);
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => AddWorkOrderPageMobile(copyFrom: workOrder),
        fullscreenDialog: true,
      ),
    )
        .then((result) async {
      if (result == 'refresh') {
        final storage = ref.read(storageServiceProvider);
        final techId =
            storage.getFromSession('logged_in_emp_id')?.toString() ?? '';
        await ref
            .read(technicianWorkOrderProvider)
            .loadTechnicianWorkOrders(techId);
        if (context.mounted) {
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

  void _editWorkOrder(BuildContext context, WidgetRef ref) {
    final parentMessenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (context) => EditWorkOrderDialog(workOrder: workOrder),
    ).then((result) async {
      if (result == true) {
        final storage = ref.read(storageServiceProvider);
        final techId =
            storage.getFromSession('logged_in_emp_id')?.toString() ?? '';
        await ref
            .read(technicianWorkOrderProvider)
            .loadTechnicianWorkOrders(techId);
        parentMessenger.showSnackBar(
          SnackBar(
            content: Text('Updated Successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    });
  }

  void _cancelWorkOrder(BuildContext context, WidgetRef ref) {
    final parentMessenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (context) => CancelWorkOrderDialog(workOrder: workOrder),
    ).then((result) async {
      if (result == true) {
        final storage = ref.read(storageServiceProvider);
        final techId =
            storage.getFromSession('logged_in_emp_id')?.toString() ?? '';
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
