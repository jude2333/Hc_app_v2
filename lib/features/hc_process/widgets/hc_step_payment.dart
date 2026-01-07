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

    String finishMode = 'normal';
    String finishLabel = 'Finish Work Order';

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
            state, notifier, 'gpay', 'GPay / UPI', Icons.phone_android),
        _buildPaymentOption(state, notifier, 'card', 'Card', Icons.credit_card),
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
        _buildSummaryCard(state),
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

  Widget _buildSummaryCard(HCProcessState state) {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Summary',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const Divider(),
            Text('Patient: ${state.workOrder?.patientName ?? "N/A"}'),
            Text('Tests: ${state.selectedTests.length}'),
            Text('Bill Amount: ₹${state.billAmount}'),
            Text('Amount Received: ₹${state.amountReceived}'),
            Text('Photos Uploaded: ${state.uploadedPhotoPaths.length}'),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecialFinish(
      HCProcessState state, String mode, String clientType, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment & Finish',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
        _buildSummaryCard(state),
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
