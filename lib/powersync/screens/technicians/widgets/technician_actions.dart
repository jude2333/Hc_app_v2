import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import 'package:anderson_crm_flutter/providers/work_order_provider.dart';
import '../../add_work_order.dart';
import '../../edit_work_order_dialog.dart';
import '../../cancel_work_order_dialog.dart';
import '../../hc_process_page.dart';

/// Technician-specific action buttons for work order rows.
/// Includes: Copy, Start HC Process, Edit, Cancel actions.
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
          icon: const Icon(Icons.content_copy, size: 18, color: Colors.grey),
          onPressed: () => _copyWorkOrder(context, ref),
          tooltip: 'Copy',
        ),
        if (showActions) ...[
          IconButton(
            icon: const Icon(Icons.play_circle_outline,
                size: 20, color: Colors.green),
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
            icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
            onPressed: () => _editWorkOrder(context, ref),
            tooltip: 'Edit',
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.red),
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
        await ref.read(workOrderProvider).loadTechnicianWorkOrders(techId);
        if (context.mounted) {
          parentMessenger.showSnackBar(
            const SnackBar(
              content: Text('Copied Successfully'),
              backgroundColor: Colors.green,
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
        await ref.read(workOrderProvider).loadTechnicianWorkOrders(techId);
        parentMessenger.showSnackBar(
          const SnackBar(
            content: Text('Updated Successfully'),
            backgroundColor: Colors.green,
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
        await ref.read(workOrderProvider).loadTechnicianWorkOrders(techId);
        parentMessenger.showSnackBar(
          const SnackBar(
            content: Text('Cancelled Successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }
}
