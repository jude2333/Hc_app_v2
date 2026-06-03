import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/hc_process_state.dart';
import '../providers/hc_process_provider.dart';
import '../providers/hc_process_controller.dart';

class HCStepPayment extends ConsumerStatefulWidget {
  final String workOrderId;
  final VoidCallback? onFinish;

  const HCStepPayment({
    Key? key,
    required this.workOrderId,
    this.onFinish,
  }) : super(key: key);

  @override
  ConsumerState<HCStepPayment> createState() => _HCStepPaymentState();
}

class _HCStepPaymentState extends ConsumerState<HCStepPayment> {
  final TextEditingController _gpayRefController =
      TextEditingController(text: 'Later');
  final TextEditingController _remarksController = TextEditingController();

  @override
  void dispose() {
    _gpayRefController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _finish(String mode) async {
    final controller =
        ref.read(hcProcessControllerProvider(widget.workOrderId));
    final notifier = ref.read(hcProcessProvider(widget.workOrderId).notifier);

    notifier.setRemarks(_remarksController.text);

    final success = await controller.finishSteps(mode);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Work Order Completed Successfully!')),
      );
      widget.onFinish?.call();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error completing work order')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hcProcessProvider(widget.workOrderId));
    final notifier = ref.read(hcProcessProvider(widget.workOrderId).notifier);

    if (state.b2bClient) {
      return _buildSpecialFinish(state, 'b2b', 'B2B Client', Colors.purple);
    }

    if (state.trialClient) {
      return _buildSpecialFinish(state, 'trial', 'Trial Client', Colors.teal);
    }

    if (state.creditClient) {
      return _buildSpecialFinish(
          state, 'credit', 'Credit Client', Colors.indigo);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment & Finish',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text('Payment Method:',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildPaymentOption(state, notifier, 'cash', 'Cash', Icons.money),
        _buildPaymentOption(
            state, notifier, 'gpay', 'GPay', Icons.phone_android),
        if (state.paymentMethod == 'gpay') ...[
          const SizedBox(height: 16),
          TextField(
            controller: _gpayRefController,
            onChanged: (value) => notifier.setGpayRef(value),
            decoration: const InputDecoration(
              labelText: 'GPay Reference',
              border: OutlineInputBorder(),
            ),
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _remarksController,
          onChanged: (value) => notifier.setRemarks(value),
          decoration: const InputDecoration(
            labelText: 'Remarks (Optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 24),
        _buildDetailedSummaryCard(state),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: state.isLoading ? null : () => _finish('normal'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            icon: state.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_circle),
            label:
                Text(state.isLoading ? 'Processing...' : 'Finish Work Order'),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentOption(
    HCProcessState state,
    HCProcessNotifier notifier,
    String value,
    String label,
    IconData icon,
  ) {
    return RadioListTile<String>(
      value: value,
      groupValue: state.paymentMethod,
      onChanged: (v) => notifier.setPaymentMethod(v ?? 'cash'),
      title: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  Widget _buildDetailedSummaryCard(HCProcessState state) {
    final hasDiscount = state.discount > 0;
    final discountLabel = state.isDiscountFlat
        ? '₹${state.discount.toStringAsFixed(0)} off'
        : '${state.discount.toStringAsFixed(0)}% off';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long, size: 20, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'Bill Summary',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _summaryRow(
              'Patient',
              state.workOrder?.patientName ?? 'N/A',
              isLabel: true,
            ),
            _summaryRow(
              'Tests',
              '${state.selectedTests.length} test(s)',
              isLabel: true,
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            _summaryRow(
              'Test Amount',
              '₹${state.billAmount.toStringAsFixed(0)}',
            ),
            if (hasDiscount)
              _summaryRow(
                'Discount ($discountLabel)',
                '- ₹${(state.billAmount - state.amountAfterDiscount).toStringAsFixed(0)}',
                valueColor: Colors.red.shade600,
              ),
            if (hasDiscount)
              _summaryRow(
                'After Discount',
                '₹${state.amountAfterDiscount.toStringAsFixed(0)}',
              ),
            if (state.hcCharges > 0)
              _summaryRow(
                'Home Collection Charges',
                '+ ₹${state.hcCharges.toStringAsFixed(0)}',
                valueColor: Colors.orange.shade700,
              ),
            if (state.disposableCharges > 0)
              _summaryRow(
                'Disposable Charges',
                '+ ₹${state.disposableCharges.toStringAsFixed(0)}',
                valueColor: Colors.orange.shade700,
              ),
            const SizedBox(height: 8),
            const Divider(height: 1, thickness: 1.5),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Amount to Collect',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '₹${state.amountReceived.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            _summaryRow(
              'Prescriptions Uploaded',
              '${state.uploadedPhotoPaths.length} photo(s)',
              isLabel: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value,
      {bool isLabel = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isLabel ? 13 : 14,
                color: isLabel ? Colors.grey.shade600 : Colors.black87,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isLabel ? 13 : 14,
              fontWeight: isLabel ? FontWeight.normal : FontWeight.w600,
              color: valueColor ??
                  (isLabel ? Colors.grey.shade600 : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialFinish(
      HCProcessState state, String mode, String clientType, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment & Finish',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.business, color: color),
              const SizedBox(width: 8),
              Text(clientType,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _remarksController,
          decoration: const InputDecoration(
            labelText: 'Remarks (Optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 24),
        _buildDetailedSummaryCard(state),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: state.isLoading ? null : () => _finish(mode),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            icon: state.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_circle),
            label: Text(
                state.isLoading ? 'Processing...' : 'Complete for $clientType'),
          ),
        ),
      ],
    );
  }
}
