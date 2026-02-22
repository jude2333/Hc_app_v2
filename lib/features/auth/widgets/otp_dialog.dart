import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';

class OtpDialog extends ConsumerStatefulWidget {
  final String mobile;
  final VoidCallback onDismiss;
  final VoidCallback onSuccess;

  const OtpDialog({
    super.key,
    required this.mobile,
    required this.onDismiss,
    required this.onSuccess,
  });

  @override
  ConsumerState<OtpDialog> createState() => _OtpDialogState();
}

class _OtpDialogState extends ConsumerState<OtpDialog> {
  final _otpController = TextEditingController();
  final _focusNode = FocusNode();

  // ── Glass design tokens (matching login_screen) ──
  static const _kHeadingColor = Color(0xFF222222);
  static const _kSubheadingColor = Color(0xFF555555);
  static const _kHintColor = Color(0xFF999999);
  static final _kFieldFillColor = Colors.white.withOpacity(0.22);
  static final _kFieldBorderColor = Colors.white.withOpacity(0.40);
  static const _kCardBlur = 22.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final notifier = ref.read(authProvider.notifier);
    final success = await notifier.verifyOtp();
    if (success && mounted) {
      widget.onSuccess();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final notifier = ref.read(authProvider.notifier);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: _kCardBlur, sigmaY: _kCardBlur),
          child: Container(
            width: 400,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.white.withOpacity(0.20),
              border: Border.all(
                color: Colors.white.withOpacity(0.45),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 40,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ──
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFF7941D).withOpacity(0.85),
                        const Color(0xFFE07D0A).withOpacity(0.85),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.lock_outline_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'OTP Verification',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Enter the code sent to your phone',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          notifier.dismissOtpDialog();
                          widget.onDismiss();
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                ),

                // ── Body ──
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Phone number display
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: _kFieldFillColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _kFieldBorderColor),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.phone_android,
                              color: _kSubheadingColor.withOpacity(0.7),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '+91 ${widget.mobile}',
                              style: const TextStyle(
                                color: _kHeadingColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // OTP input
                      Container(
                        decoration: BoxDecoration(
                          color: _kFieldFillColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: authState.hasError
                                ? Colors.red.withOpacity(0.6)
                                : _kFieldBorderColor,
                          ),
                        ),
                        child: TextFormField(
                          controller: _otpController,
                          focusNode: _focusNode,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _kHeadingColor,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 8,
                          ),
                          decoration: InputDecoration(
                            hintText: '• • • • • •',
                            hintStyle: TextStyle(
                              color: _kHintColor.withOpacity(0.6),
                              fontSize: 24,
                              letterSpacing: 8,
                            ),
                            border: InputBorder.none,
                            counterText: '',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          onChanged: notifier.setOtp,
                          onFieldSubmitted: (_) => _submit(),
                        ),
                      ),

                      // Error message
                      if (authState.hasError) ...[
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red.shade600,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              authState.errorMessage ?? '',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Verify button (glass style)
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFFF7941D).withOpacity(0.85),
                                    const Color(0xFFE07D0A).withOpacity(0.85),
                                  ],
                                ),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.30),
                                  width: 1.0,
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap:
                                      authState.isOtpLoading ? null : _submit,
                                  child: Center(
                                    child: authState.isOtpLoading
                                        ? const SizedBox(
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            'Verify OTP',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Resend link
                      TextButton(
                        onPressed: () {},
                        child: Text(
                          "Didn't receive code? Resend",
                          style: TextStyle(
                            color: _kSubheadingColor.withOpacity(0.8),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showOtpDialog({
  required BuildContext context,
  required String mobile,
  required VoidCallback onDismiss,
  required VoidCallback onSuccess,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.4),
    builder: (context) => OtpDialog(
      mobile: mobile,
      onDismiss: onDismiss,
      onSuccess: onSuccess,
    ),
  );
}
