import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/hc_process_provider.dart';
import '../providers/hc_process_controller.dart';
import 'package:anderson_crm_flutter/features/price_list/screens/add_test_dialog.dart';

class HCStepTests extends ConsumerWidget {
  final String workOrderId;

  const HCStepTests({Key? key, required this.workOrderId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hcProcessProvider(workOrderId));
    final notifier = ref.read(hcProcessProvider(workOrderId).notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Tests'),
            ),
            const SizedBox(width: 8),
            if (!state.trialClient) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: state.cghsPrice
                      ? Colors.orange.shade50
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: state.cghsPrice
                        ? Colors.orange.shade300
                        : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 28,
                      child: Switch(
                        value: state.cghsPrice,
                        onChanged: (v) => notifier.setCghsPrice(v),
                        activeColor: Colors.orange,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'CGHS Rate',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: state.cghsPrice
                            ? Colors.orange.shade800
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        if (state.selectedTests.isNotEmpty) ...[
          Row(
            children: [
              const Text(
                'Selected Tests:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              if (state.cghsPrice) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Text(
                    'CGHS Rates Applied',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          ...state.selectedTests.asMap().entries.map((entry) {
            final test = entry.value;

            final baseCost =
                double.tryParse(test['base_cost']?.toString() ?? '0') ?? 0;
            final cghsCost =
                double.tryParse(test['cghs_price']?.toString() ?? '0') ?? 0;
            final displayPrice =
                state.cghsPrice && cghsCost > 0 ? cghsCost : baseCost;
            final isCghsRate = state.cghsPrice && cghsCost > 0;

            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(test['invest_name'] ?? 'Unknown'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${displayPrice.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isCghsRate
                              ? Colors.orange.shade700
                              : Colors.black87,
                        ),
                      ),
                      if (isCghsRate && baseCost > 0)
                        Text(
                          'MRP ₹${baseCost.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                    ],
                  ),
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
            'Total: ₹${state.totalAmount.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (state.cghsPrice)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'CGHS rates applied where available',
                style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
              ),
            ),
        ],
      ],
    );
  }
}
