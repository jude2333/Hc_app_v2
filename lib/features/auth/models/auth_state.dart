import 'package:flutter/foundation.dart';

/// Represents a user role with id and name
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

/// Login flow step
enum LoginStep {
  enterMobile,
  verifyOtp,
  selectRole,
}

/// Immutable state for the authentication flow
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

  /// Whether there's an error to display
  bool get hasError => errorMessage != null && errorMessage!.isNotEmpty;

  /// Whether mobile number is valid (10 digits)
  bool get isMobileValid => mobile.length == 10;

  /// Whether OTP is valid (6 digits)
  bool get isOtpValid => otp.length == 6;

  /// Whether user has multiple roles
  bool get hasMultipleRoles => roles.length > 1;

  /// Whether role selection is needed
  bool get needsRoleSelection => hasMultipleRoles && selectedRoleId == null;

  /// Create a copy with updated fields
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

  /// Initial state
  static const initial = AuthState();
}
