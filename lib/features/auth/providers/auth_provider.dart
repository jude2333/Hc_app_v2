import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_state.dart';
import '../repositories/auth_repository.dart';

/// State notifier for authentication flow
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(AuthState.initial) {
    _loadRememberedMobile();
  }

  /// Load remembered mobile from storage
  Future<void> _loadRememberedMobile() async {
    final mobile = _repository.getRememberedMobile();
    if (mobile.isNotEmpty) {
      state = state.copyWith(
        mobile: mobile,
        rememberMobile: true,
      );
    }
  }

  /// Update mobile number
  void setMobile(String mobile) {
    state = state.copyWith(mobile: mobile, clearError: true);
  }

  /// Update OTP
  void setOtp(String otp) {
    state = state.copyWith(otp: otp, clearError: true);
  }

  /// Toggle remember mobile
  Future<void> setRememberMobile(bool remember) async {
    state = state.copyWith(rememberMobile: remember);
    await _repository.setRememberMobile(state.mobile, remember);
  }

  /// Clear error after delay
  void _clearErrorAfterDelay() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        state = state.copyWith(clearError: true);
      }
    });
  }

  /// Send OTP to mobile number
  Future<void> sendOtp() async {
    if (!state.isMobileValid) {
      state = state.copyWith(errorMessage: "Incorrect Mobile Number");
      _clearErrorAfterDelay();
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // First check if user exists
      final loginResult = await _repository.login(state.mobile);

      if (loginResult == "200") {
        debugPrint("[AuthNotifier] User found, sending OTP");
        await _repository.reloadStorageCaches();

        // Check if this is a remembered user
        final rememberedMobile = _repository.getRememberedMobile();
        if (rememberedMobile.isNotEmpty && state.mobile == rememberedMobile) {
          // Auto-login for remembered user
          await _handleRoleSelection();
        } else {
          // Send OTP
          await _repository.sendOtp(state.mobile);
          state = state.copyWith(
            showOtpDialog: true,
            currentStep: LoginStep.verifyOtp,
            isLoading: false,
          );
        }
      } else if (loginResult.contains("Error") ||
          loginResult.contains("NO_MATCHES")) {
        state = state.copyWith(
          errorMessage: "User Not Found",
          isLoading: false,
        );
        _clearErrorAfterDelay();
      } else if (loginResult.contains("NEW_APP")) {
        state = state.copyWith(
          errorMessage:
              "Please download and install the new version of this app.",
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          errorMessage: "Login failed: $loginResult",
          isLoading: false,
        );
        _clearErrorAfterDelay();
      }
    } catch (e) {
      debugPrint("[AuthNotifier] Error in sendOtp: $e");
      state = state.copyWith(
        errorMessage: e.toString(),
        isLoading: false,
      );
      _clearErrorAfterDelay();
    }
  }

  /// Verify OTP and complete login
  Future<bool> verifyOtp() async {
    if (!state.isOtpValid) {
      state = state.copyWith(errorMessage: "Incorrect OTP");
      _clearErrorAfterDelay();
      return false;
    }

    state = state.copyWith(isOtpLoading: true, clearError: true);

    try {
      final isValid = await _repository.verifyOtp(state.mobile, state.otp);

      if (isValid) {
        // Login after OTP verification
        final loginResult = await _repository.login(state.mobile);

        if (loginResult == "200") {
          await _repository.reloadStorageCaches();
          await _handleRoleSelection();
          await _repository.writeLoginLog();
          state = state.copyWith(showOtpDialog: false, isOtpLoading: false);
          return true;
        } else {
          state = state.copyWith(
            errorMessage: "Login failed after OTP verification",
            showOtpDialog: false,
            isOtpLoading: false,
          );
          _clearErrorAfterDelay();
          return false;
        }
      } else {
        state = state.copyWith(
          errorMessage: "Invalid OTP",
          isOtpLoading: false,
        );
        _clearErrorAfterDelay();
        return false;
      }
    } catch (e) {
      debugPrint("[AuthNotifier] Error in verifyOtp: $e");
      state = state.copyWith(
        errorMessage: e.toString(),
        isOtpLoading: false,
      );
      _clearErrorAfterDelay();
      return false;
    }
  }

  /// Handle role selection logic
  Future<void> _handleRoleSelection() async {
    final roleIds = _repository.getRoleIdsFromSession();

    if (roleIds.isEmpty) {
      state = state.copyWith(
        errorMessage: "No roles assigned to user",
        isLoading: false,
      );
      _clearErrorAfterDelay();
      return;
    }

    // Fetch role names
    final roles = await _repository.fetchRoles(roleIds);
    state = state.copyWith(roles: roles);

    if (roles.length > 1) {
      // Multiple roles - show selection
      state = state.copyWith(
        currentStep: LoginStep.selectRole,
        isLoading: false,
      );
      debugPrint("[AuthNotifier] Multiple roles found, showing selector");
    } else if (roles.length == 1) {
      // Single role - auto-select
      await selectRole(roles.first.id, roles.first.name);
    }
  }

  /// Select a role and navigate to dashboard
  Future<bool> selectRole(String roleId, String roleName) async {
    state = state.copyWith(isLoading: true, selectedRoleId: roleId);

    try {
      await _repository.saveSelectedRole(roleId, roleName);
      debugPrint("[AuthNotifier] Role selected: $roleName");

      // Update state to trigger navigation in UI
      // Change currentStep to allow navigation condition to pass
      state = state.copyWith(
        isLoading: false,
        currentStep: LoginStep.enterMobile, // Reset step so navigation triggers
      );
      return true;
    } catch (e) {
      debugPrint("[AuthNotifier] Error selecting role: $e");
      state = state.copyWith(
        errorMessage: "Failed to select role",
        isLoading: false,
        selectedRoleId: null,
      );
      _clearErrorAfterDelay();
      return false;
    }
  }

  /// Dismiss OTP dialog
  void dismissOtpDialog() {
    state = state.copyWith(
      showOtpDialog: false,
      otp: '',
      currentStep: LoginStep.enterMobile,
    );
  }

  /// Quick login for development (bypasses OTP)
  Future<void> quickLogin() async {
    if (!state.isMobileValid) {
      state = state.copyWith(errorMessage: "Incorrect Mobile Number");
      _clearErrorAfterDelay();
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final loginResult = await _repository.login(state.mobile);

      if (loginResult == "200") {
        debugPrint("[AuthNotifier] Quick login successful");
        await _repository.reloadStorageCaches();
        await _handleRoleSelection();
      } else if (loginResult.contains("Error") ||
          loginResult.contains("NO_MATCHES")) {
        state = state.copyWith(
          errorMessage: "User Not Found",
          isLoading: false,
        );
        _clearErrorAfterDelay();
      } else if (loginResult.contains("NEW_APP")) {
        state = state.copyWith(
          errorMessage:
              "Please download and install the new version of this app.",
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          errorMessage: "Login failed: $loginResult",
          isLoading: false,
        );
        _clearErrorAfterDelay();
      }
    } catch (e) {
      debugPrint("[AuthNotifier] Error in quickLogin: $e");
      state = state.copyWith(
        errorMessage: "Login error: ${e.toString()}",
        isLoading: false,
      );
      _clearErrorAfterDelay();
    }
  }

  /// Reset state
  void reset() {
    state = AuthState.initial;
  }
}

/// Auth state provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.read(authRepositoryProvider);
  return AuthNotifier(repository);
});
