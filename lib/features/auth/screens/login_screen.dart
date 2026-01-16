import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../models/auth_state.dart';
import '../widgets/otp_dialog.dart';

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

    // Listen for state changes
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
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1A1A2E),
              const Color(0xFF16213E),
              const Color(0xFF0F3460),
            ],
          ),
        ),
        child: KeyboardListener(
          focusNode: FocusNode(),
          onKeyEvent: (KeyEvent event) {
            if (event is KeyDownEvent) {
              // Both Enter and Escape trigger quick login (for dev convenience)
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
                    // Logo/Brand section
                    _buildBrandSection(),

                    const SizedBox(height: 40),

                    // Login card
                    Container(
                      width: isDesktop ? 420 : double.infinity,
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: _buildLoginCard(authState, notifier),
                    ),

                    const SizedBox(height: 24),

                    // Footer
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
        // Logo container with glow effect
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                Colors.orange.shade400,
                Colors.deepOrange.shade600,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.4),
                blurRadius: 30,
                spreadRadius: 5,
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
        Text(
          'Healthcare Management System',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.7),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard(AuthState authState, AuthNotifier notifier) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome text
              const Text(
                'Welcome back',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
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

              // Error message
              if (authState.hasError)
                _buildErrorBanner(authState.errorMessage ?? ''),

              // Mobile input
              _buildMobileInput(authState, notifier),

              const SizedBox(height: 20),

              // Role selector (if needed)
              if (authState.currentStep == LoginStep.selectRole)
                _buildRoleSelector(authState, notifier),

              // Remember checkbox
              _buildRememberCheckbox(authState, notifier),

              const SizedBox(height: 24),

              // Login button
              _buildLoginButton(authState, notifier),

              const SizedBox(height: 16),

              // Get OTP button
              _buildOtpButton(authState, notifier),
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
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
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
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
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
              dropdownColor: const Color(0xFF16213E),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              icon: Icon(Icons.keyboard_arrow_down,
                  color: Colors.white.withOpacity(0.6)),
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
                  // Navigate directly to dashboard (matching old behavior)
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
            side: BorderSide(color: Colors.white.withOpacity(0.4)),
            checkColor: Colors.white,
            activeColor: Colors.orange,
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
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.orange.withOpacity(0.5),
          elevation: 0,
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
          side: BorderSide(color: Colors.white.withOpacity(0.3)),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sms_outlined,
                size: 18, color: Colors.white.withOpacity(0.8)),
            const SizedBox(width: 8),
            Text(
              'Login with OTP',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.9),
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
            color: Colors.white.withOpacity(0.4),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '© 2024 Anderson Healthcare',
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
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
