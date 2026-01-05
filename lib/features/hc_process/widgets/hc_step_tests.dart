import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/hc_process_provider.dart';
import '../providers/hc_process_controller.dart';
import 'package:anderson_crm_flutter/features/price_list/screens/add_test_dialog.dart';

/// Step 2: Tests Selection Widget
class HCStepTests extends ConsumerWidget {
  final String workOrderId;

  const HCStepTests({Key? key, required this.workOrderId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hcProcessProvider(workOrderId));
    final notifier = ref.read(hcProcessProvider(workOrderId).notifier);
    final controller = ref.read(hcProcessControllerProvider(workOrderId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Action row
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () async {
                if (state.workOrder == null) return;

                final result = await showDialog(
                  context: context,
                  builder: (context) => AddTestDialog(
                    workOrder: state.workOrder!.toMap(),
                    useCghsPrice: state.cghsPrice,
                  ),
                );

                if (result != null && result is Map<String, dynamic>) {
                  if (result['testitems'] != null) {
                    notifier.setSelectedTests(
                      List<Map<String, dynamic>>.from(result['testitems']),
                    );
                  }
                  if (result['total'] != null) {
                    final total = (result['total'] as num).toDouble();
                    notifier.setTotalAmount(total);
                    notifier.setBillAmount(total);
                  }
                  if (result['proformalocation'] != null) {
                    notifier.setProformaInvLoc(
                        result['proformalocation'].toString());
                  }

                  // Auto-proceed if tests were selected
                  if (state.selectedTests.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      controller.afterSecondStep();
                    });
                  }
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Tests'),
            ),
            const SizedBox(width: 8),

            // CGHS checkbox
            if (!state.trialClient) ...[
              Checkbox(
                value: state.cghsPrice,
                onChanged: (v) => notifier.setCghsPrice(v ?? false),
              ),
              const Text('Use CGHS Price'),
            ],
          ],
        ),
        const SizedBox(height: 16),

        // Selected tests list
        if (state.selectedTests.isNotEmpty) ...[
          const Text(
            'Selected Tests:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          ...state.selectedTests.asMap().entries.map((entry) {
            final test = entry.value;
            return ListTile(
              title: Text(test['invest_name'] ?? 'Unknown'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('₹${test['base_cost'] ?? '0'}'),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => notifier.removeTest(entry.key),
                  ),
                ],
              ),
            );
          }),
          const Divider(),
          Text(
            'Total: ₹${state.totalAmount}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ],
    );
  }
}
