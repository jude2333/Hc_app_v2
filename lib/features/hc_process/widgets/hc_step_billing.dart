import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/hc_process_provider.dart';
import '../providers/hc_process_controller.dart';

class HCStepBilling extends ConsumerStatefulWidget {
  final String workOrderId;

  const HCStepBilling({Key? key, required this.workOrderId}) : super(key: key);

  @override
  ConsumerState<HCStepBilling> createState() => _HCStepBillingState();
}

class _HCStepBillingState extends ConsumerState<HCStepBilling> {
  late TextEditingController _discountController;
  late TextEditingController _hcChargesController;
  late TextEditingController _dispChargesController;

  @override
  void initState() {
    super.initState();
    _discountController = TextEditingController(text: '0');
    _hcChargesController = TextEditingController(text: '50');
    _dispChargesController = TextEditingController(text: '30');
  }

  @override
  void dispose() {
    _discountController.dispose();
    _hcChargesController.dispose();
    _dispChargesController.dispose();
    super.dispose();
  }

  void _onDiscountChanged(String value) {
    final notifier = ref.read(hcProcessProvider(widget.workOrderId).notifier);
    final controller =
        ref.read(hcProcessControllerProvider(widget.workOrderId));
    notifier.setDiscount(double.tryParse(value) ?? 0);
    controller.calculateDiscount();
  }

  void _onHcChargesChanged(String value) {
    final notifier = ref.read(hcProcessProvider(widget.workOrderId).notifier);
    final controller =
        ref.read(hcProcessControllerProvider(widget.workOrderId));
    notifier.setHcCharges(double.tryParse(value) ?? 0);
    controller.calculateDiscount();
  }

  void _onDispChargesChanged(String value) {
    final notifier = ref.read(hcProcessProvider(widget.workOrderId).notifier);
    final controller =
        ref.read(hcProcessControllerProvider(widget.workOrderId));
    notifier.setDisposableCharges(double.tryParse(value) ?? 0);
    controller.calculateDiscount();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hcProcessProvider(widget.workOrderId));

    final bool areChargesEnabled = state.creditClient ? state.cghsPrice : true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bill Amount: ₹${state.billAmount}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (state.creditClient)
                  const Text(
                    'Credit Client - Limited Charges',
                    style: TextStyle(color: Colors.orange),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _discountController,
          enabled: areChargesEnabled,
          onChanged: _onDiscountChanged,
          decoration: const InputDecoration(
            labelText: 'Discount (%)',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _hcChargesController,
          enabled: areChargesEnabled,
          onChanged: _onHcChargesChanged,
          decoration: const InputDecoration(
            labelText: 'HC Charges (₹)',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _dispChargesController,
          enabled: areChargesEnabled,
          onChanged: _onDispChargesChanged,
          decoration: const InputDecoration(
            labelText: 'Disposable Charges (₹)',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        Card(
          color: Colors.green.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('After Discount: ₹${state.amountAfterDiscount}'),
                const SizedBox(height: 8),
                Text(
                  'Total Receivable: ₹${state.amountReceived}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
