import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/hc_process_provider.dart';
import '../providers/hc_process_controller.dart';
import '../widgets/hc_step_delay.dart';
import '../widgets/hc_step_tests.dart';
import '../widgets/hc_step_billing.dart';
import '../widgets/hc_step_otp.dart';
import '../widgets/hc_step_prescription.dart';
import '../widgets/hc_step_payment.dart';

class HCProcessPage extends ConsumerStatefulWidget {
  final String workOrderId;

  const HCProcessPage({
    Key? key,
    required this.workOrderId,
  }) : super(key: key);

  @override
  ConsumerState<HCProcessPage> createState() => _HCProcessPageState();
}

class _HCProcessPageState extends ConsumerState<HCProcessPage> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(hcProcessControllerProvider(widget.workOrderId)).loadWorkOrder();
    });
  }

  Future<void> _onStepContinue() async {
    final state = ref.read(hcProcessProvider(widget.workOrderId));
    final controller =
        ref.read(hcProcessControllerProvider(widget.workOrderId));
    final notifier = ref.read(hcProcessProvider(widget.workOrderId).notifier);

    switch (state.currentStep) {
      case 0:
        final success = await controller.afterFirstStep();
        if (success == false) {
          _showSnackBar('Please provide a proper delay reason');
        }
        break;
      case 1:
        await controller.afterSecondStep();
        break;
      case 2:
        await controller.afterThirdStep();
        break;
      case 3:
        final verified = controller.verifyOtp(state.enteredOtp);
        if (!verified) {
          _showSnackBar('Invalid OTP');
        }
        break;
      case 4:
        if (state.uploadedPhotoPaths.isEmpty) {
          _showSnackBar('Please upload at least one prescription photo');
        } else {
          notifier.setCurrentStep(5);
        }
        break;
    }
  }

  void _onStepCancel() {
    final state = ref.read(hcProcessProvider(widget.workOrderId));
    if (state.currentStep > 0) {
      ref
          .read(hcProcessProvider(widget.workOrderId).notifier)
          .setCurrentStep(state.currentStep - 1);
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hcProcessProvider(widget.workOrderId));

    if (state.isLoading && state.workOrder == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('HC Process'),
          backgroundColor: Colors.orange,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (state.errorMessage != null && state.workOrder == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('HC Process'),
          backgroundColor: Colors.orange,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(state.errorMessage!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref
                    .read(hcProcessControllerProvider(widget.workOrderId))
                    .loadWorkOrder(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.workOrder == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('HC Process'),
          backgroundColor: Colors.orange,
        ),
        body: const Center(child: Text('Loading work order...')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('HC Process - ${state.workOrder!.patientName}'),
        backgroundColor: Colors.orange,
        actions: [
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
      body: Stepper(
        currentStep: state.currentStep,
        onStepContinue: _onStepContinue,
        onStepCancel: _onStepCancel,
        controlsBuilder: _buildStepperControls,
        steps: [
          Step(
            title: const Text('Arrival'),
            content: HCStepDelay(workOrderId: widget.workOrderId),
            isActive: state.currentStep >= 0,
            state:
                state.currentStep > 0 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('Tests'),
            content: HCStepTests(workOrderId: widget.workOrderId),
            isActive: state.currentStep >= 1,
            state:
                state.currentStep > 1 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('Billing'),
            content: HCStepBilling(workOrderId: widget.workOrderId),
            isActive: state.currentStep >= 2,
            state:
                state.currentStep > 2 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('OTP'),
            content: HCStepOtp(workOrderId: widget.workOrderId),
            isActive: state.currentStep >= 3,
            state:
                state.currentStep > 3 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('Prescription'),
            content: HCStepPrescription(workOrderId: widget.workOrderId),
            isActive: state.currentStep >= 4,
            state:
                state.currentStep > 4 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('Payment'),
            content: HCStepPayment(
              workOrderId: widget.workOrderId,
              onFinish: () => Navigator.of(context).pop(true),
            ),
            isActive: state.currentStep >= 5,
            state:
                state.currentStep == 5 ? StepState.indexed : StepState.complete,
          ),
        ],
      ),
    );
  }

  Widget _buildStepperControls(BuildContext context, ControlsDetails details) {
    final state = ref.watch(hcProcessProvider(widget.workOrderId));

    return Padding(
      padding: const EdgeInsets.only(top: 20.0),
      child: Row(
        children: [
          if (details.stepIndex < 5)
            ElevatedButton(
              onPressed: state.isLoading ? null : details.onStepContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: state.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Continue'),
            ),
          const SizedBox(width: 12),
          if (details.stepIndex > 0)
            TextButton(
              onPressed: state.isLoading ? null : details.onStepCancel,
              child: const Text('Back'),
            ),
        ],
      ),
    );
  }
}
