import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/features/add_work_order/add_work_order_page.dart';
import 'package:anderson_crm_flutter/components/edit_work_order_dialog.dart';
import 'package:anderson_crm_flutter/components/cancel_work_order_dialog.dart';
import 'package:anderson_crm_flutter/features/hc_process/screens/hc_process_page.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import '../providers/technician_work_order_provider.dart';
import 'add_tests_post_completion_page.dart';
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
          onPressed: () => _copyWorkOrder(context, ref),
          tooltip: 'Copy',
        ),
        if (canAddTests)
          IconButton(
            icon: Icon(Icons.post_add,
                size: AppSizes.iconSm, color: AppColors.primary),
            onPressed: () => _addTestsPostCompletion(context),
            tooltip: 'Add Tests',
          ),
        if (showActions) ...[
          IconButton(
            icon: Icon(Icons.play_circle_outline,
                size: AppSizes.iconSm, color: AppColors.success),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      HCProcessPage(workOrderId: workOrder.docId),
                ),
              );
              if (context.mounted) {
                _checkSugarTestOnReturn(context, ref);
              }
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

  /// After HC process completes, check if a Glucose Fasting test was present
  /// and prompt the technician to book Glucose (PP).
  void _checkSugarTestOnReturn(BuildContext context, WidgetRef ref) {
    final storage = ref.read(storageServiceProvider);
    final sugarDocId = storage.getFromSession('sugar_tests');

    if (sugarDocId.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('Glucose (PP) Test',
            style: TextStyle(color: AppColors.primary)),
        content:
            const Text('Do you want to book Glucose(PP) for this patient?'),
        actions: [
          TextButton(
            onPressed: () {
              storage.setSession('sugar_tests', '');
              Navigator.pop(ctx);
            },
            child:
                Text('No', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              storage.setSession('sugar_tests', '');

              final notifier =
                  ref.read(technicianWONotifierProvider.notifier);
              final wo = notifier.getWorkOrderById(sugarDocId);
              if (wo != null && context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddWorkOrderPage(
                      copyFrom: wo.copyWith(visitTime: ''),
                    ),
                    fullscreenDialog: true,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  void _addTestsPostCompletion(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddTestsPostCompletionPage(workOrder: workOrder),
        fullscreenDialog: true,
      ),
    );
  }

  void _copyWorkOrder(BuildContext context, WidgetRef ref) {
    final parentMessenger = ScaffoldMessenger.of(context);
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => AddWorkOrderPage(copyFrom: workOrder),
        fullscreenDialog: true,
      ),
    )
        .then((result) async {
      if (result == 'refresh' && context.mounted) {
        parentMessenger.showSnackBar(
          SnackBar(
            content: Text('Copied Successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    });
  }

  void _editWorkOrder(BuildContext context, WidgetRef ref) {
    final parentMessenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (context) => EditWorkOrderDialog(workOrder: workOrder),
    ).then((result) async {
      if (result == true && context.mounted) {
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
      if (result == true && context.mounted) {
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
