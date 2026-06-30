import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/features/add_work_order/add_work_order_page.dart';
import 'package:anderson_crm_flutter/components/edit_work_order_dialog.dart';
import 'package:anderson_crm_flutter/components/cancel_work_order_dialog.dart';
import 'package:anderson_crm_flutter/features/hc_process/screens/hc_process_page.dart';
import 'package:anderson_crm_flutter/features/technician_work_order/widgets/add_tests_post_completion_page.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import 'package:anderson_crm_flutter/features/technician_work_order/providers/technician_work_order_provider.dart';
import 'package:anderson_crm_flutter/features/theme/theme.dart';

class TechnicianActionsHelper {
  TechnicianActionsHelper._();
  static Future<void> startHCProcess(
      BuildContext context, WidgetRef ref, WorkOrder workOrder) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HCProcessPage(workOrderId: workOrder.docId),
      ),
    );
    if (context.mounted) {
      checkSugarTestOnReturn(context, ref);
    }
  }

  static void checkSugarTestOnReturn(BuildContext context, WidgetRef ref) {
    final storage = ref.read(storageServiceProvider);
    final sugarDocId = storage.getFromSession('sugar_tests').toString();
    if (sugarDocId.isEmpty) return;

    showSugarTestDialog(context, ref, sugarDocId);
  }

  static void showSugarTestDialog(
      BuildContext context, WidgetRef ref, String docId) {
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
              ref.read(storageServiceProvider).setSession('sugar_tests', '');
              Navigator.pop(ctx);
            },
            child: Text('No', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              ref.read(storageServiceProvider).setSession('sugar_tests', '');
              await handleSugarTestCopy(context, ref, docId);
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

  static Future<void> handleSugarTestCopy(
      BuildContext context, WidgetRef ref, String docId) async {
    final notifier = ref.read(technicianWONotifierProvider.notifier);
    final workOrder = notifier.getWorkOrderById(docId);
    if (workOrder != null && context.mounted) {
      final workOrderForCopy = workOrder.copyWith(visitTime: '');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddWorkOrderPage(copyFrom: workOrderForCopy),
          fullscreenDialog: true,
        ),
      );
    }
  }

  static void copyWorkOrder(BuildContext context, WorkOrder workOrder) {
    final parentMessenger = ScaffoldMessenger.of(context);
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => AddWorkOrderPage(copyFrom: workOrder),
        fullscreenDialog: true,
      ),
    )
        .then((result) {
      if (result == 'refresh' && context.mounted) {
        parentMessenger.showSnackBar(
          SnackBar(
            content: const Text('Copied Successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    });
  }

  static void editWorkOrder(BuildContext context, WorkOrder workOrder) {
    final parentMessenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (context) => EditWorkOrderDialog(workOrder: workOrder),
    ).then((result) {
      if (result == true && context.mounted) {
        parentMessenger.showSnackBar(
          SnackBar(
            content: const Text('Updated Successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    });
  }

  static void cancelWorkOrder(BuildContext context, WorkOrder workOrder) {
    final parentMessenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (context) => CancelWorkOrderDialog(workOrder: workOrder),
    ).then((result) {
      if (result == true && context.mounted) {
        parentMessenger.showSnackBar(
          SnackBar(
            content: const Text('Cancelled Successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    });
  }

  static void addTestsPostCompletion(
      BuildContext context, WorkOrder workOrder) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTestsPostCompletionPage(workOrder: workOrder),
        fullscreenDialog: true,
      ),
    );
  }
}
