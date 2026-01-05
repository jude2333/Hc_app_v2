import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:anderson_crm_flutter/util.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';

class Authorize {
  static Future<List<Map<String, dynamic>>> getMenus(WidgetRef ref) async {
    final storage = ref.read(storageServiceProvider);
    final roleName = storage.getFromSession("role_name");
    final department = storage.getFromSession("department_name");

    if (department == "HOME COLLECTION" || department == "ALL DEPARTMENTS") {
      if (roleName == "TECHNICIAN") {
        return [
          {
            'icon': "mdi-order-bool-ascending",
            'title': "My Work Orders",
            'vertical': "MyWork",
            'link': "my_work_orders",
          },
        ];
      } else if (roleName == "BILLING") {
        return [
          {
            'icon': "mdi-order-bool-ascending",
            'title': "Billing Work Orders",
            'vertical': "billingWork",
            'link': "billing_work_orders",
          },
        ];
      } else if (roleName == "SAMPLE RECEIVING") {
        return [
          {
            'icon': "mdi-test-tube",
            'title': "Sample Receiving",
            'vertical': "samplereceiving",
            'link': "lab_sample_receiving",
          },
        ];
      } else if (roleName == "MANAGER" || roleName == "RECEPTIONIST") {
        return [
          {
            'icon': "mdi-point-of-sale",
            'title': "Work Orders",
            'vertical': "Work Orders",
            'link': "work_orders",
          },
          {
            'icon': "mdi-motion-sensor",
            'title': "Users",
            'vertical': "Users",
            'link': "users",
          },
        ];
      }
    }
    return [];
  }
}
