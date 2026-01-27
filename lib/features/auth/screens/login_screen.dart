import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../models/auth_state.dart';
import '../widgets/otp_dialog.dart';
import '../../theme/app_colors.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _dialogShowing = false;
  final _mobileController = TextEditingController();
  final _mobileFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final authState = ref.read(authProvider);
        _mobileController.text = authState.mobile;
        _mobileFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _mobileController.dispose();
    _mobileFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final notifier = ref.read(authProvider.notifier);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 600;

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.showOtpDialog && !_dialogShowing) {
        _dialogShowing = true;
        _showOtpDialog(next.mobile);
      }

      if (next.selectedRoleId != null &&
          next.currentStep != LoginStep.selectRole &&
          !next.isLoading) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.go('/dashboard');
          }
        });
      }
    });

    return Scaffold(
      body: Container(
        height: size.height,
        width: size.width,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            // colors: [
            //   Color(0xFF0A4D68),
            //   Color(0xFF088395),
            //   Color(0xFF05BFDB),
            //   Color(0xFF00FFCA),
            // ],
            colors: [
              AppColors.textSecondary,
              AppColors.textSecondary,
              AppColors.textSecondary,
              AppColors.textSecondary,
            ],
            stops: [0.0, 0.35, 0.7, 1.0],
          ),
        ),
        child: KeyboardListener(
          focusNode: FocusNode(),
          onKeyEvent: (KeyEvent event) {
            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.escape) {
                notifier.quickLogin();
              }
            }
          },
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildBrandSection(),
                    const SizedBox(height: 40),
                    Container(
                      width: isDesktop ? 420 : double.infinity,
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: _buildLoginCard(authState, notifier),
                    ),
                    const SizedBox(height: 24),
                    _buildFooter(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandSection() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF7941D),
                Color(0xFFE07D0A),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF7941D).withOpacity(0.4),
                blurRadius: 25,
                spreadRadius: 3,
              ),
            ],
          ),
          child: const Icon(
            Icons.medical_services_rounded,
            size: 48,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Anderson CRM',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Diagnostics & Labs',
          style: TextStyle(
            fontSize: 14,
            fontStyle: FontStyle.italic,
            color: Color(0xFFF7941D),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Adding Health to Life...',
          style: TextStyle(
            fontSize: 12,
            fontStyle: FontStyle.italic,
            color: Colors.white.withOpacity(0.7),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard(AuthState authState, AuthNotifier notifier) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Colors.transparent,
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1.0,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 1.5,
                  decoration: BoxDecoration(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.0),
                        Colors.white.withOpacity(0.6),
                        Colors.white.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome back',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to continue to your account',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (authState.hasError)
                      _buildErrorBanner(authState.errorMessage ?? ''),
                    _buildMobileInput(authState, notifier),
                    const SizedBox(height: 20),
                    if (authState.currentStep == LoginStep.selectRole)
                      _buildRoleSelector(authState, notifier),
                    _buildRememberCheckbox(authState, notifier),
                    const SizedBox(height: 24),
                    _buildLoginButton(authState, notifier),
                    const SizedBox(height: 16),
                    _buildOtpButton(authState, notifier),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade900.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade400.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade300, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.red.shade200, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileInput(AuthState authState, AuthNotifier notifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mobile Number',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
            ),
          ),
          child: TextFormField(
            controller: _mobileController,
            focusNode: _mobileFocusNode,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              letterSpacing: 1,
            ),
            decoration: InputDecoration(
              prefixIcon: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '🇮🇳 +91',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                    Container(
                      height: 24,
                      width: 1,
                      margin: const EdgeInsets.only(left: 12),
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ],
                ),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0),
              border: InputBorder.none,
              hintText: 'Enter mobile number',
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.4),
              ),
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
            keyboardType: TextInputType.phone,
            maxLength: 10,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: notifier.setMobile,
            onFieldSubmitted: (_) => notifier.quickLogin(),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleSelector(AuthState authState, AuthNotifier notifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Role',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: authState.selectedRoleId,
              hint: Text(
                'Choose your role',
                style: TextStyle(color: Colors.white.withOpacity(0.5)),
              ),
              isExpanded: true,
              dropdownColor: const Color(0xFF0A4D68),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              icon: Icon(Icons.keyboard_arrow_down,
                  color: Colors.white.withOpacity(0.7)),
              items: authState.roles.map((role) {
                return DropdownMenuItem<String>(
                  value: role.id,
                  child: Text(role.name),
                );
              }).toList(),
              onChanged: (value) async {
                if (value != null) {
                  final role = authState.roles.firstWhere((r) => r.id == value);
                  final success = await notifier.selectRole(role.id, role.name);
                  if (success && mounted) {
                    context.go('/dashboard');
                  }
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildRememberCheckbox(AuthState authState, AuthNotifier notifier) {
    return Row(
      children: [
        SizedBox(
          height: 24,
          width: 24,
          child: Checkbox(
            value: authState.rememberMobile,
            onChanged: (value) => notifier.setRememberMobile(value ?? false),
            side: BorderSide(color: Colors.white.withOpacity(0.5)),
            checkColor: Colors.white,
            activeColor: const Color(0xFFF7941D),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Remember my mobile number',
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton(AuthState authState, AuthNotifier notifier) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: authState.isLoading ? null : notifier.quickLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF7941D),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFF7941D).withOpacity(0.5),
          elevation: 4,
          shadowColor: const Color(0xFFF7941D).withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: authState.isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Sign In',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }

  Widget _buildOtpButton(AuthState authState, AuthNotifier notifier) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: authState.isLoading ? null : notifier.sendOtp,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF00669B)),
          foregroundColor: const Color(0xFF00669B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sms_outlined, size: 18, color: Color(0xFF00669B)),
            SizedBox(width: 8),
            Text(
              'Login with OTP',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF00669B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          'Version 1.0.0',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '© 2024 Anderson Healthcare',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  void _showOtpDialog(String mobile) {
    showOtpDialog(
      context: context,
      mobile: mobile,
      onDismiss: () {
        _dialogShowing = false;
      },
      onSuccess: () {
        _dialogShowing = false;
        Navigator.of(context).pop();
        if (mounted) {
          context.go('/dashboard');
        }
      },
    ).then((_) {
      _dialogShowing = false;
    });
  }
}
