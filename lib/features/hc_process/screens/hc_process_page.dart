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
import '../../theme/theme.dart';

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
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        ref
            .read(hcProcessControllerProvider(widget.workOrderId))
            .loadWorkOrder();
      }
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
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return _buildLoadingScaffold();
    }

    final state = ref.watch(hcProcessProvider(widget.workOrderId));

    if (state.isLoading && state.workOrder == null) {
      return _buildLoadingScaffold();
    }

    if (state.errorMessage != null && state.workOrder == null) {
      return _buildErrorScaffold(state.errorMessage!);
    }

    if (state.workOrder == null) {
      return _buildLoadingScaffold(message: 'Loading work order...');
    }

    return _buildMainContent(state);
  }

  Widget _buildLoadingScaffold({String? message}) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.gradientStart, AppColors.gradientEnd],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: 24),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScaffold(String errorMessage) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.gradientStart, AppColors.gradientEnd],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(32),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Something went wrong',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    errorMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => ref
                        .read(hcProcessControllerProvider(widget.workOrderId))
                        .loadWorkOrder(),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gradientStart,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(dynamic state) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            elevation: 0,
            backgroundColor: AppColors.gradientStart,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.gradientStart, AppColors.gradientEnd],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text(
                          'HC Process',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.person_outline,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    state.workOrder!.patientName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (state.isLoading) ...[
                              const SizedBox(width: 12),
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
        body: SingleChildScrollView(
          child: Column(
            children: [
              _buildProgressIndicator(state.currentStep),
              Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: ColorScheme.light(
                    primary: AppColors.gradientStart,
                    secondary: AppColors.gradientEnd,
                  ),
                ),
                child: Stepper(
                  currentStep: state.currentStep,
                  onStepContinue: _onStepContinue,
                  onStepCancel: _onStepCancel,
                  controlsBuilder: _buildStepperControls,
                  type: StepperType.vertical,
                  physics: const NeverScrollableScrollPhysics(),
                  elevation: 0,
                  steps: _buildSteps(state),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(int currentStep) {
    const totalSteps = 6;
    final progress = (currentStep + 1) / totalSteps;

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step ${currentStep + 1} of $totalSteps',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}% Complete',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gradientStart,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.gradientStart.withValues(alpha: 0.1),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.gradientStart),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(totalSteps, (index) {
              final isCompleted = index < currentStep;
              final isCurrent = index == currentStep;
              return _buildStepDot(index, isCompleted, isCurrent);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStepDot(int index, bool isCompleted, bool isCurrent) {
    final labels = ['Arrival', 'Tests', 'Billing', 'OTP', 'Rx', 'Pay'];

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: isCurrent ? 36 : 28,
          height: isCurrent ? 36 : 28,
          decoration: BoxDecoration(
            color: isCompleted
                ? AppColors.success
                : isCurrent
                    ? AppColors.gradientStart
                    : AppColors.gradientStart.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: AppColors.gradientStart.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: isCurrent ? Colors.white : AppColors.gradientStart,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          labels[index],
          style: TextStyle(
            fontSize: 10,
            fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
            color:
                isCurrent ? AppColors.gradientStart : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  List<Step> _buildSteps(dynamic state) {
    return [
      Step(
        title: _buildStepTitle(
            'Arrival', Icons.location_on_outlined, 0, state.currentStep),
        content: HCStepDelay(workOrderId: widget.workOrderId),
        isActive: state.currentStep >= 0,
        state: state.currentStep > 0 ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: _buildStepTitle(
            'Tests', Icons.science_outlined, 1, state.currentStep),
        content: HCStepTests(workOrderId: widget.workOrderId),
        isActive: state.currentStep >= 1,
        state: state.currentStep > 1 ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: _buildStepTitle(
            'Billing', Icons.receipt_outlined, 2, state.currentStep),
        content: HCStepBilling(workOrderId: widget.workOrderId),
        isActive: state.currentStep >= 2,
        state: state.currentStep > 2 ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: _buildStepTitle(
            'OTP Verification', Icons.lock_outline, 3, state.currentStep),
        content: HCStepOtp(workOrderId: widget.workOrderId),
        isActive: state.currentStep >= 3,
        state: state.currentStep > 3 ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: _buildStepTitle(
            'Prescription', Icons.description_outlined, 4, state.currentStep),
        content: HCStepPrescription(workOrderId: widget.workOrderId),
        isActive: state.currentStep >= 4,
        state: state.currentStep > 4 ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: _buildStepTitle(
            'Payment', Icons.payment_outlined, 5, state.currentStep),
        content: HCStepPayment(
          workOrderId: widget.workOrderId,
          onFinish: () => Navigator.of(context).pop(true),
        ),
        isActive: state.currentStep >= 5,
        state: state.currentStep == 5 ? StepState.indexed : StepState.complete,
      ),
    ];
  }

  Widget _buildStepTitle(
      String title, IconData icon, int stepIndex, int currentStep) {
    final isActive = stepIndex <= currentStep;
    final isCompleted = stepIndex < currentStep;

    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isCompleted
              ? AppColors.success
              : isActive
                  ? AppColors.gradientStart
                  : AppColors.textSecondary,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStepperControls(BuildContext context, ControlsDetails details) {
    final state = ref.watch(hcProcessProvider(widget.workOrderId));

    return Container(
      margin: const EdgeInsets.only(top: 24),
      child: Row(
        children: [
          if (details.stepIndex < 5)
            Expanded(
              child: ElevatedButton(
                onPressed: state.isLoading ? null : details.onStepContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gradientStart,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: state.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
              ),
            ),
          if (details.stepIndex > 0) ...[
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: state.isLoading ? null : details.onStepCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.arrow_back_rounded, size: 18),
                  SizedBox(width: 6),
                  Text('Back'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
