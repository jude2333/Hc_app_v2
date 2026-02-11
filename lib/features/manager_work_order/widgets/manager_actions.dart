import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/providers/work_order_provider.dart';
import 'package:anderson_crm_flutter/features/add_work_order/add_work_order_page.dart';
import '../providers/manager_work_order_provider.dart';
import '../controllers/manager_assignment_controller.dart';
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
        builder: (context) => AddWorkOrderPage(copyFrom: workOrder),
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
        builder: (context) => AddWorkOrderPage(existingWorkOrder: workOrder),
        fullscreenDialog: true,
      ),
    ).then((res) async {
      if (res == 'refresh') {
        _refresh(context, ref, 'Updated');
      } else if (res == 'cancelled') {
        _refresh(context, ref, 'Cancelled');
        if (context.mounted) {
          _showCancellationNotificationDialog(context, ref);
        }
      }
    });
  }

  /// Shows a dialog asking the manager whether to notify the patient about
  /// the cancellation via SMS, WhatsApp, and/or Email.
  /// Mirrors Vue's `close_edit_screen` → `msg_dialog` flow in desktop_view.vue.
  void _showCancellationNotificationDialog(
      BuildContext context, WidgetRef ref) {
    bool sendSms = true;
    bool sendWhatsApp = true;
    bool sendEmail = workOrder.email.isNotEmpty;

    final parentMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Container(
                padding: AppPadding.card,
                color: AppColors.primary,
                child: Text('Cancelled Successfully',
                    style: TextStyle(color: AppColors.textOnPrimary))),
            content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Do you wish to inform ${workOrder.patientName} (Mob: ${workOrder.mobile}) about the cancellation?'),
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

                  final controller =
                      ref.read(managerAssignmentControllerProvider);
                  try {
                    await controller.sendCancellationMessages(
                      workOrder: workOrder,
                      sendSms: sendSms,
                      sendWhatsApp: sendWhatsApp,
                      sendEmail: sendEmail,
                    );
                    parentMessenger.showSnackBar(SnackBar(
                        content: Text('Cancellation notifications sent'),
                        backgroundColor: AppColors.success));
                  } catch (e) {
                    parentMessenger.showSnackBar(SnackBar(
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
                final date = ref.read(managerSelectedDatePod);
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
    final date = ref.read(managerSelectedDatePod);
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
