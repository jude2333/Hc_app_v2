import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_state.dart';
import '../repositories/auth_repository.dart';

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(AuthState.initial) {
    _loadRememberedMobile();
  }

  Future<void> _loadRememberedMobile() async {
    final mobile = await _repository.getRememberedMobileAsync();
    if (mobile.isNotEmpty) {
      state = state.copyWith(
        mobile: mobile,
        rememberMobile: true,
      );
    }
  }

  void setMobile(String mobile) {
    state = state.copyWith(mobile: mobile, clearError: true);
  }

  void setOtp(String otp) {
    state = state.copyWith(otp: otp, clearError: true);
  }

  Future<void> setRememberMobile(bool remember) async {
    state = state.copyWith(rememberMobile: remember);
    await _repository.setRememberMobile(state.mobile, remember);
  }

  void _clearErrorAfterDelay() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        state = state.copyWith(clearError: true);
      }
    });
  }

  Future<void> sendOtp() async {
    if (!state.isMobileValid) {
      state = state.copyWith(errorMessage: "Incorrect Mobile Number");
      _clearErrorAfterDelay();
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final loginResult = await _repository.login(state.mobile);

      if (loginResult == "200") {
        debugPrint("[AuthNotifier] User found, sending OTP");
        await _repository.reloadStorageCaches();
        await _repository.sendOtp(state.mobile);
        state = state.copyWith(
          showOtpDialog: true,
          currentStep: LoginStep.verifyOtp,
          isLoading: false,
        );
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
        final loginResult = await _repository.login(state.mobile);

        if (loginResult == "200") {
          await _repository.reloadStorageCaches();
          await _repository.writeLoginLog();
          await _handleRoleSelection();
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

    final roles = await _repository.fetchRoles(roleIds);
    state = state.copyWith(roles: roles);

    if (roles.length > 1) {
      state = state.copyWith(
        currentStep: LoginStep.selectRole,
        isLoading: false,
      );
      debugPrint("[AuthNotifier] Multiple roles found, showing selector");
    } else if (roles.length == 1) {
      await selectRole(roles.first.id, roles.first.name);
    }
  }

  Future<bool> selectRole(String roleId, String roleName) async {
    state = state.copyWith(isLoading: true, selectedRoleId: roleId);

    try {
      await _repository.saveSelectedRole(roleId, roleName);
      debugPrint("[AuthNotifier] Role selected: $roleName");

      state = state.copyWith(
        isLoading: false,
        currentStep: LoginStep.enterMobile,
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

  void dismissOtpDialog() {
    state = state.copyWith(
      showOtpDialog: false,
      otp: '',
      currentStep: LoginStep.enterMobile,
    );
  }

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

  void reset() {
    state = AuthState(
      mobile: state.mobile,
      rememberMobile: state.rememberMobile,
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.read(authRepositoryProvider);
  return AuthNotifier(repository);
});
