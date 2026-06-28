import 'dart:ui';
import 'package:anderson_crm_flutter/config/settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';

import '../providers/auth_provider.dart';
import '../models/auth_state.dart';
import '../widgets/otp_dialog.dart';
import 'package:anderson_crm_flutter/features/theme/theme.dart';
import 'package:anderson_crm_flutter/features/tracking/services/location_service.dart';
import 'package:anderson_crm_flutter/services/app_update_service.dart';
import 'package:anderson_crm_flutter/features/core/widgets/common/update_dialog.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import 'package:anderson_crm_flutter/features/shell/providers/shell_providers.dart';
import 'package:anderson_crm_flutter/providers/notification_provider.dart';
import 'package:anderson_crm_flutter/providers/db_handler_provider.dart';
import 'package:anderson_crm_flutter/providers/couch_db_provider.dart';
import 'package:anderson_crm_flutter/features/session/storage_service.dart';
import 'package:anderson_crm_flutter/services/postgresService.dart';

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

  static const _kAndersonBlue = Color(0xFF1B4F8A);
  static const _kCardBlur = 5.0;
  static const _kCardBorderRadius = 20.0;
  static const _kCardPadding = 32.0;
  static const _kDesktopCardWidth = 420.0;

  static final _kCardFillColor = Colors.white.withOpacity(0.08);
  static final _kCardBorderColor = Colors.white.withOpacity(0.55);
  static final _kFieldFillColor = Colors.white.withOpacity(0.15);
  static final _kFieldBorderColor = Colors.white.withOpacity(0.50);

  static const _kHeadingColor = Color(0xFF222222);
  static const _kSubheadingColor = Color(0xFF555555);
  static const _kLabelColor = Color(0xFF333333);

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
        // Commented out to fix app breakage
        // _checkSessionAndAutoLogin();

        final authState = ref.read(authProvider);
        _mobileController.text = authState.mobile;
        _mobileFocusNode.requestFocus();

        _checkForAppUpdate();
      }
    });
  }

  // Future<void> _checkSessionAndAutoLogin() async {
  //   // Disabled OTP bypass to prevent app breakage.
  //   return;
  // }

  // Future<void> _performAutoLogoutCleanup(StorageService storage) async {
  //   try {
  //     ref.read(liveNotificationProvider.notifier).reset();
  //     ref.read(dbHandlerProvider).stopSync();
  //     ref.read(couchDbClientProvider).clearCache();
  //   } catch (_) {}

  //   await storage.clearSession();
  //   ref.read(signedInProvider.notifier).state = false;
  // }

  Future<void> _checkForAppUpdate() async {
    final updateInfo = await AppUpdateService.checkForUpdate();
    if (updateInfo != null && mounted) {
      showUpdateDialog(context, updateInfo);
    }
  }

  @override
  void dispose() {
    _shimmerController.stop();
    _shimmerController.dispose();
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

      // Sync controller when remembered mobile loads asynchronously
      if (previous != null &&
          next.mobile != previous.mobile &&
          next.mobile != _mobileController.text) {
        _mobileController.text = next.mobile;
        _mobileController.selection = TextSelection.fromPosition(
          TextPosition(offset: next.mobile.length),
        );
      }

      if (next.selectedRoleId != null &&
          next.currentStep != LoginStep.selectRole &&
          !next.isLoading) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.read(signedInProvider.notifier).state = true;
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
            if (event.logicalKey == LogicalKeyboardKey.enter) {
              notifier.sendOtp();
            } else if (event.logicalKey == LogicalKeyboardKey.escape) {
              notifier.quickLogin();
            }
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/login_bgg.webp',
              fit: BoxFit.cover,
              width: size.width,
              height: size.height,
              filterQuality: FilterQuality.high,
            ),
            Container(
              color: Colors.white.withOpacity(0.05),
            ),
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
                      const SizedBox(height: 30),
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
                color: _kCardFillColor,
                border: Border.all(color: _kCardBorderColor, width: 1.2),
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
              Padding(
                padding: EdgeInsets.all(isDesktop ? _kCardPadding : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Welcome back',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.backgroundSmoke,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Sign in to continue to your account',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.backgroundSmoke,
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (authState.hasError)
                      _buildErrorBanner(authState.errorMessage ?? ''),
                    _buildMobileInput(authState, notifier),
                    const SizedBox(height: 18),
                    if (authState.currentStep == LoginStep.selectRole)
                      _buildRoleSelector(authState, notifier),
                    _buildRememberCheckbox(authState, notifier),
                    const SizedBox(height: 22),
                    // Sign In button commented out — security: bypasses OTP verification
                    // _buildSignInButton(authState, notifier),
                    // const SizedBox(height: 14),
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

  Widget _buildMobileInput(AuthState authState, AuthNotifier notifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Mobile Number',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.backgroundSmoke,
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
              hintStyle: TextStyle(color: AppColors.backgroundSmoke),
              counterText: '',
              contentPadding: EdgeInsets.symmetric(vertical: 16),
            ),
            keyboardType: TextInputType.phone,
            maxLength: 10,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: notifier.setMobile,
            onFieldSubmitted: (_) => notifier.sendOtp(),
          ),
        ),
      ],
    );
  }

  IconData _roleIcon(String roleName) {
    switch (roleName.toUpperCase()) {
      case 'MANAGER':
        return Icons.groups_rounded;
      case 'TECHNICIAN':
        return Icons.biotech_rounded;
      case 'BILLING':
        return Icons.receipt_long_rounded;
      case 'ADMIN':
        return Icons.admin_panel_settings_rounded;
      default:
        return Icons.badge_rounded;
    }
  }

  Future<bool> _checkLocationPermission() async {
    if (kIsWeb) {
      final locationService = LocationService();
      final granted = await locationService.requestPermissions();
      if (granted) return true;

      if (mounted) await _showWebLocationDialog();
      return false;
    }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) await _showGpsOffDialog();
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) await _showPermissionDeniedDialog(false);
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) await _showPermissionDeniedDialog(true);
      return false;
    }

    return true;
  }

  Future<void> _showGpsOffDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.gps_off, size: 48, color: Colors.orange),
        title: const Text('Turn On GPS',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'Your device GPS is turned off. \n\nPlease turn on GPS and try again.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.location_on, size: 18),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Geolocator.openLocationSettings();
            },
            label:
                const Text('Enable GPS', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Future<void> _showPermissionDeniedDialog(bool isPermanent) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.location_off, size: 48, color: Colors.red),
        title: const Text('Location Permission Required',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          isPermanent
              ? 'Location permission was permanently denied. Tap "Open Settings" below, then enable Location permission for this app.'
              : 'Location permission is required for technician login. Your live location helps with work order tracking.\n\nTap "Grant Permission" to allow access.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          if (isPermanent) ...[
            ElevatedButton.icon(
              icon: const Icon(Icons.settings, size: 18),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAndersonBlue,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Geolocator.openAppSettings();
              },
              label: const Text('Open Settings',
                  style: TextStyle(color: Colors.white)),
            ),
          ] else ...[
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAndersonBlue,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Grant Permission',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Future<void> _showWebLocationDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.location_off, size: 48, color: Colors.red),
        title: const Text('Location Required',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Location access was blocked by your browser. To enable it:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('1. Click the 🔒 lock icon in the address bar',
                      style: TextStyle(fontSize: 13, height: 1.6)),
                  Text('2. Find "Location" and set to "Allow"',
                      style: TextStyle(fontSize: 13, height: 1.6)),
                  Text('3. Click "Try Again" below',
                      style: TextStyle(fontSize: 13, height: 1.6)),
                ],
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kAndersonBlue,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Try Again', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
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
            color: AppColors.backgroundSmoke.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 12),
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
                      if (role.name == 'TECHNICIAN') {
                        final locationOk = await _checkLocationPermission();
                        if (!locationOk) return;
                      }
                      final success =
                          await notifier.selectRole(role.id, role.name);
                      if (success && mounted) {
                        ref.read(signedInProvider.notifier).state = true;
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

  Widget _buildRememberCheckbox(AuthState authState, AuthNotifier notifier) {
    return Row(
      children: [
        SizedBox(
          height: 22,
          width: 22,
          child: Checkbox(
            value: authState.rememberMobile,
            onChanged: (value) => notifier.setRememberMobile(value ?? false),
            side: BorderSide(color: AppColors.backgroundSmoke.withOpacity(0.5)),
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
            color: AppColors.backgroundSmoke,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

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
                            color: AppColors.backgroundSmoke,
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
                          size: 18, color: AppColors.backgroundSmoke),
                      SizedBox(width: 8),
                      Text(
                        'Login with OTP',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.backgroundSmoke,
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

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          Settings.version,
          style: TextStyle(
            color: AppColors.backgroundSmoke.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '© 2024 Anderson Healthcare',
          style: TextStyle(
            color: AppColors.backgroundSmoke.withOpacity(0.8),
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
          final authState = ref.read(authProvider);
          // Multi-role: role selector will show on login screen
          if (authState.currentStep != LoginStep.selectRole) {
            ref.read(signedInProvider.notifier).state = true;
            context.go('/dashboard');
          }
        }
      },
    ).then((_) {
      _dialogShowing = false;
    });
  }
}
