import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/hc_process_provider.dart';
import '../providers/hc_process_controller.dart';

/// Step 1: Delay Reason Widget
class HCStepDelay extends ConsumerStatefulWidget {
  final String workOrderId;

  const HCStepDelay({Key? key, required this.workOrderId}) : super(key: key);

  @override
  ConsumerState<HCStepDelay> createState() => _HCStepDelayState();
}

class _HCStepDelayState extends ConsumerState<HCStepDelay> {
  late TextEditingController _delayController;

  @override
  void initState() {
    super.initState();
    _delayController = TextEditingController();
  }

  @override
  void dispose() {
    _delayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hcProcessProvider(widget.workOrderId));
    final notifier = ref.read(hcProcessProvider(widget.workOrderId).notifier);

    // Sync controller with state
    if (_delayController.text != state.delayReason) {
      _delayController.text = state.delayReason;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Delay warning
        if (state.delayMins.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Delayed by ${state.delayMins} minutes',
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

        // Delay reason input
        TextField(
          controller: _delayController,
          onChanged: (value) => notifier.setDelayReason(value),
          decoration: const InputDecoration(
            labelText: 'Delay Reason',
            hintText: 'Enter reason for delay or "On Time"',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),

        // Patient info
        if (state.workOrder != null) ...[
          Text(
            'Patient: ${state.workOrder!.patientName}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text('Mobile: ${state.clientMobile}'),
          Text('Appointment: ${state.workOrder!.visitTime}'),
        ],
      ],
    );
  }
}
