import 'dart:ui';
import 'package:anderson_crm_flutter/config/settings.dart';
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

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _dialogShowing = false;
  final _mobileController = TextEditingController();
  final _mobileFocusNode = FocusNode();

  // ── Liquid glass design tokens ──
  static const _kAndersonBlue = Color(0xFF1B4F8A);
  static const _kCardBlur = 5.0;
  static const _kCardBorderRadius = 20.0;
  static const _kCardPadding = 32.0;
  static const _kDesktopCardWidth = 420.0;

  // Card glass colors — keep opacity LOW to let background show through
  static final _kCardFillColor = Colors.white.withOpacity(0.08);
  static final _kCardBorderColor = Colors.white.withOpacity(0.55);
  static final _kFieldFillColor = Colors.white.withOpacity(0.15);
  static final _kFieldBorderColor = Colors.white.withOpacity(0.50);

  // Text colors on glass (dark text for light translucent bg)
  static const _kHeadingColor = Color(0xFF222222);
  static const _kSubheadingColor = Color(0xFF555555);
  static const _kLabelColor = Color(0xFF333333);
  static const _kHintColor = Color(0xFF999999);
  static const _kFooterColor = Color(0xFF444444);

  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
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
    _shimmerController.dispose();
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
      body: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (KeyEvent event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.escape) {
              notifier.quickLogin();
            }
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Layer 1: Full‑bleed background image ──
            Image.asset(
              'assets/images/login_bg.webp',
              fit: BoxFit.cover,
              width: size.width,
              height: size.height,
              filterQuality: FilterQuality.high,
            ),

            // ── Layer 2: Subtle overlay to improve card contrast ──
            Container(
              color: Colors.white.withOpacity(0.05),
            ),

            // ── Layer 3: Login card (centred) ──
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 24 : 20,
                    vertical: 24,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: isDesktop ? _kDesktopCardWidth : double.infinity,
                        constraints:
                            const BoxConstraints(maxWidth: _kDesktopCardWidth),
                        child: _buildLiquidGlassCard(
                            authState, notifier, isDesktop),
                      ),
                      const SizedBox(height: 24),
                      _buildFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  LIQUID GLASS CARD
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildLiquidGlassCard(
      AuthState authState, AuthNotifier notifier, bool isDesktop) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_kCardBorderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _kCardBlur, sigmaY: _kCardBlur),
        child: ListenableBuilder(
          listenable: _shimmerController,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_kCardBorderRadius),
                // Glass fill: translucent white
                color: _kCardFillColor,
                border: Border.all(color: _kCardBorderColor, width: 1.2),
                // Subtle glass shadow
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 30,
                    spreadRadius: 0,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.15),
                    blurRadius: 1,
                    spreadRadius: 0,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              child: child,
            );
          },
          child: Stack(
            children: [
              // ── Top highlight shimmer (glass edge reflection) ──
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ListenableBuilder(
                  listenable: _shimmerController,
                  builder: (context, _) {
                    return Container(
                      height: 1.5,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(_kCardBorderRadius)),
                        gradient: LinearGradient(
                          begin: Alignment(
                              -1.0 + 2.0 * _shimmerController.value, 0),
                          end: Alignment(
                              1.0 + 2.0 * _shimmerController.value, 0),
                          colors: [
                            Colors.white.withOpacity(0.0),
                            Colors.white.withOpacity(0.7),
                            Colors.white.withOpacity(0.0),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // ── Card content ──
              Padding(
                padding: EdgeInsets.all(isDesktop ? _kCardPadding : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Heading ──
                    const Text(
                      'Welcome back',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: _kHeadingColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Sign in to continue to your account',
                      style: TextStyle(
                        fontSize: 14,
                        color: _kSubheadingColor,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Error banner ──
                    if (authState.hasError)
                      _buildErrorBanner(authState.errorMessage ?? ''),

                    // ── Mobile input ──
                    _buildMobileInput(authState, notifier),
                    const SizedBox(height: 18),

                    // ── Role selector (if applicable) ──
                    if (authState.currentStep == LoginStep.selectRole)
                      _buildRoleSelector(authState, notifier),

                    // ── Remember checkbox ──
                    _buildRememberCheckbox(authState, notifier),
                    const SizedBox(height: 22),

                    // ── Sign In button (glass style) ──
                    _buildSignInButton(authState, notifier),
                    const SizedBox(height: 14),

                    // ── OTP button (glass outlined) ──
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

  // ═══════════════════════════════════════════════════════════════════════════
  //  ERROR BANNER
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade50.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade300.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.red.shade700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  MOBILE NUMBER INPUT
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMobileInput(AuthState authState, AuthNotifier notifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mobile Number',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _kLabelColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _kFieldFillColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kFieldBorderColor),
          ),
          child: TextFormField(
            controller: _mobileController,
            focusNode: _mobileFocusNode,
            style: const TextStyle(
              color: _kHeadingColor,
              fontSize: 16,
              letterSpacing: 1,
            ),
            decoration: const InputDecoration(
              prefixIcon: SizedBox(width: 12),
              prefixIconConstraints: BoxConstraints(minWidth: 12),
              border: InputBorder.none,
              hintText: 'Enter mobile number',
              hintStyle: TextStyle(color: _kHintColor),
              counterText: '',
              contentPadding: EdgeInsets.symmetric(vertical: 16),
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

  // ═══════════════════════════════════════════════════════════════════════════
  //  ROLE SELECTOR  —  Liquid glass role tiles
  // ═══════════════════════════════════════════════════════════════════════════

  IconData _roleIcon(String roleName) {
    switch (roleName.toUpperCase()) {
      case 'MANAGER':
        return Icons.groups_rounded;
      case 'TECHNICIAN':
        return Icons.biotech_rounded;
      case 'BILLING':
        return Icons.receipt_long_rounded;
      default:
        return Icons.badge_rounded;
    }
  }

  Widget _buildRoleSelector(AuthState authState, AuthNotifier notifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Role',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _kLabelColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose how you\'d like to sign in today',
          style: TextStyle(
            fontSize: 12,
            color: _kSubheadingColor.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 12),

        // ── Role tiles ──
        ...authState.roles.map((role) {
          final isSelected = authState.selectedRoleId == role.id;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    splashColor: Colors.white.withOpacity(0.15),
                    highlightColor: Colors.white.withOpacity(0.08),
                    onTap: () async {
                      final success =
                          await notifier.selectRole(role.id, role.name);
                      if (success && mounted) {
                        context.go('/dashboard');
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: isSelected
                            ? _kAndersonBlue.withOpacity(0.12)
                            : _kFieldFillColor,
                        border: Border.all(
                          color: isSelected
                              ? _kAndersonBlue.withOpacity(0.4)
                              : _kFieldBorderColor,
                          width: isSelected ? 1.5 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: _kAndersonBlue.withOpacity(0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        children: [
                          // Role icon
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? _kAndersonBlue.withOpacity(0.15)
                                  : Colors.white.withOpacity(0.12),
                              border: Border.all(
                                color: isSelected
                                    ? _kAndersonBlue.withOpacity(0.3)
                                    : Colors.white.withOpacity(0.3),
                              ),
                            ),
                            child: Icon(
                              _roleIcon(role.name),
                              size: 18,
                              color: isSelected
                                  ? _kAndersonBlue
                                  : _kSubheadingColor,
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Role name
                          Expanded(
                            child: Text(
                              role.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: isSelected
                                    ? _kAndersonBlue
                                    : _kHeadingColor,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),

                          // Arrow / check
                          Icon(
                            isSelected
                                ? Icons.check_circle_rounded
                                : Icons.arrow_forward_ios_rounded,
                            size: isSelected ? 20 : 14,
                            color: isSelected
                                ? _kAndersonBlue
                                : _kSubheadingColor.withOpacity(0.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),

        const SizedBox(height: 10),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  REMEMBER CHECKBOX
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildRememberCheckbox(AuthState authState, AuthNotifier notifier) {
    return Row(
      children: [
        SizedBox(
          height: 22,
          width: 22,
          child: Checkbox(
            value: authState.rememberMobile,
            onChanged: (value) => notifier.setRememberMobile(value ?? false),
            side: BorderSide(color: _kLabelColor.withOpacity(0.5)),
            checkColor: Colors.white,
            activeColor: _kAndersonBlue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          'Remember my mobile number',
          style: TextStyle(
            color: _kLabelColor,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SIGN IN BUTTON  —  Liquid glass pill
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSignInButton(AuthState authState, AuthNotifier notifier) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withOpacity(0.12),
              border: Border.all(
                color: Colors.white.withOpacity(0.55),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: authState.isLoading ? null : notifier.quickLogin,
                splashColor: Colors.white.withOpacity(0.2),
                highlightColor: Colors.white.withOpacity(0.1),
                child: Center(
                  child: authState.isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: _kHeadingColor,
                          ),
                        )
                      : const Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _kHeadingColor,
                            letterSpacing: 0.3,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  OTP BUTTON  —  Glass outlined pill
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildOtpButton(AuthState authState, AuthNotifier notifier) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withOpacity(0.06),
              border: Border.all(
                color: Colors.white.withOpacity(0.50),
                width: 1.0,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: authState.isLoading ? null : notifier.sendOtp,
                splashColor: Colors.white.withOpacity(0.15),
                highlightColor: Colors.white.withOpacity(0.08),
                child: const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sms_outlined,
                          size: 18, color: _kSubheadingColor),
                      SizedBox(width: 8),
                      Text(
                        'Login with OTP',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _kSubheadingColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  FOOTER
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          Settings.version,
          style: TextStyle(
            color: _kFooterColor.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '© 2024 Anderson Healthcare',
          style: TextStyle(
            color: _kFooterColor.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  OTP DIALOG
  // ═══════════════════════════════════════════════════════════════════════════

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
