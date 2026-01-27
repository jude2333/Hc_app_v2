import 'package:flutter/foundation.dart';

@immutable
class UserRole {
  final String id;
  final String name;

  const UserRole({required this.id, required this.name});

  factory UserRole.fromMap(Map<String, dynamic> map) {
    return UserRole(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
    );
  }
}

enum LoginStep {
  enterMobile,
  verifyOtp,
  selectRole,
}

@immutable
class AuthState {
  final String mobile;
  final String otp;
  final bool rememberMobile;
  final bool isLoading;
  final bool isOtpLoading;
  final String? errorMessage;
  final List<UserRole> roles;
  final String? selectedRoleId;
  final LoginStep currentStep;
  final bool showOtpDialog;

  const AuthState({
    this.mobile = '',
    this.otp = '',
    this.rememberMobile = false,
    this.isLoading = false,
    this.isOtpLoading = false,
    this.errorMessage,
    this.roles = const [],
    this.selectedRoleId,
    this.currentStep = LoginStep.enterMobile,
    this.showOtpDialog = false,
  });

  bool get hasError => errorMessage != null && errorMessage!.isNotEmpty;

  bool get isMobileValid => mobile.length == 10;

  bool get isOtpValid => otp.length == 6;

  bool get hasMultipleRoles => roles.length > 1;

  bool get needsRoleSelection => hasMultipleRoles && selectedRoleId == null;

  AuthState copyWith({
    String? mobile,
    String? otp,
    bool? rememberMobile,
    bool? isLoading,
    bool? isOtpLoading,
    String? errorMessage,
    List<UserRole>? roles,
    String? selectedRoleId,
    LoginStep? currentStep,
    bool? showOtpDialog,
    bool clearError = false,
  }) {
    return AuthState(
      mobile: mobile ?? this.mobile,
      otp: otp ?? this.otp,
      rememberMobile: rememberMobile ?? this.rememberMobile,
      isLoading: isLoading ?? this.isLoading,
      isOtpLoading: isOtpLoading ?? this.isOtpLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      roles: roles ?? this.roles,
      selectedRoleId: selectedRoleId ?? this.selectedRoleId,
      currentStep: currentStep ?? this.currentStep,
      showOtpDialog: showOtpDialog ?? this.showOtpDialog,
    );
  }

  static const initial = AuthState();
}
