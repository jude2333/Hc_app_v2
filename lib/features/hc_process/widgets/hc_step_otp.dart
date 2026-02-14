import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/hc_process_state.dart';
import '../providers/hc_process_provider.dart';
import '../providers/hc_process_controller.dart';
import 'package:anderson_crm_flutter/config/settings.dart';

class HCStepOtp extends ConsumerStatefulWidget {
  final String workOrderId;
  final VoidCallback? onVerified;

  const HCStepOtp({
    Key? key,
    required this.workOrderId,
    this.onVerified,
  }) : super(key: key);

  @override
  ConsumerState<HCStepOtp> createState() => _HCStepOtpState();
}

class _HCStepOtpState extends ConsumerState<HCStepOtp> {
  final TextEditingController _otpController = TextEditingController();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _verifyOtp() {
    final controller =
        ref.read(hcProcessControllerProvider(widget.workOrderId));
    final verified = controller.verifyOtp(_otpController.text);

    if (verified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP Verified!')),
      );
      widget.onVerified?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid OTP')),
      );
    }
  }

  void _resendOtp() async {
    final controller =
        ref.read(hcProcessControllerProvider(widget.workOrderId));
    await controller.generateOtp();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('OTP resent!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hcProcessProvider(widget.workOrderId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'OTP Verification',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text('OTP sent to: ${state.clientMobile}'),
        const SizedBox(height: 16),
        if (Settings.development && state.generatedOtp.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber),
            ),
            child: Row(
              children: [
                const Icon(Icons.developer_mode, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  'Dev Mode OTP: ${state.generatedOtp}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        TextField(
          controller: _otpController,
          decoration: const InputDecoration(
            labelText: 'Enter OTP',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.lock),
          ),
          keyboardType: TextInputType.number,
          maxLength: 6,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: state.isLoading ? null : _verifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.check),
                label: const Text('Verify OTP'),
              ),
            ),
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: state.isLoading ? null : _resendOtp,
              icon: const Icon(Icons.refresh),
              label: const Text('Resend'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildEnabledMethods(state),
      ],
    );
  }

  Widget _buildEnabledMethods(HCProcessState state) {
    final methods = <String>[];
    if (state.sms == 1) methods.add('SMS');
    if (state.whatsapp == 1) methods.add('WhatsApp');
    if (state.email == 1) methods.add('Email');

    return Text(
      'Sent via: ${methods.isEmpty ? "None" : methods.join(", ")}',
      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
    );
  }
}
