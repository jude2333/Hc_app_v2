import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:anderson_crm_flutter/config/settings.dart';
import 'package:anderson_crm_flutter/features/core/util.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import 'package:anderson_crm_flutter/providers/db_handler_provider.dart';
import 'package:anderson_crm_flutter/services/postgresService.dart';
import '../models/auth_state.dart';

/// Repository for authentication-related API and database operations
class AuthRepository {
  final PostgresService _postgresService;
  final Ref _ref;

  AuthRepository(this._postgresService, this._ref);

  /// Send OTP to the given mobile number
  Future<void> sendOtp(String mobile) async {
    try {
      final data = {'mobile': mobile};
      await Dio().post(
        "${Settings.nodeUrl}/sms/send_otp",
        data: data,
        options: Options(
          responseType: ResponseType.plain,
          headers: {'withCredentials': 'true'},
        ),
      );
      debugPrint("[AuthRepository] OTP sent successfully to $mobile");
    } catch (e) {
      debugPrint("[AuthRepository] Error sending OTP: $e");
      rethrow;
    }
  }

  /// Verify OTP for the given mobile number
  /// Returns true if OTP matches
  Future<bool> verifyOtp(String mobile, String otp) async {
    try {
      final data = {
        'mobile': mobile,
        'entered_otp': otp,
      };

      final response = await Dio().post(
        "${Settings.nodeUrl}/sms/check_otp",
        data: data,
        options: Options(
          headers: {'withCredentials': 'true'},
        ),
      );

      final isMatch = response.data == "OTP_MATCH";
      debugPrint(
          "[AuthRepository] OTP verification: ${isMatch ? 'success' : 'failed'}");
      return isMatch;
    } catch (e) {
      debugPrint("[AuthRepository] Error verifying OTP: $e");
      rethrow;
    }
  }

  /// Login with mobile number
  /// Returns result code from database
  Future<String> login(String mobile) async {
    try {
      final result = await _postgresService.login(mobile, "");
      debugPrint("[AuthRepository] Login result: $result");
      return result;
    } catch (e) {
      debugPrint("[AuthRepository] Login error: $e");
      rethrow;
    }
  }

  /// Fetch role names for the given role IDs
  Future<List<UserRole>> fetchRoles(List<String> roleIds) async {
    try {
      List<UserRole> roles = [];

      for (String roleId in roleIds) {
        List<dynamic> roleNameData = await _postgresService.getRoleName(roleId);
        if (roleNameData.isNotEmpty) {
          final roleName = roleNameData[0]['role_name']?.toString() ?? '';
          roles.add(UserRole(id: roleId, name: roleName));
          debugPrint("[AuthRepository] Fetched role: $roleId -> $roleName");
        }
      }

      return roles;
    } catch (e) {
      debugPrint("[AuthRepository] Error fetching roles: $e");
      return [];
    }
  }

  /// Get role IDs from session storage
  List<String> getRoleIdsFromSession() {
    final storage = _ref.read(storageServiceProvider);
    final roleIdsStr = storage.getFromSession("final_role");

    if (roleIdsStr.isEmpty) {
      return [];
    }

    return roleIdsStr.split(',');
  }

  /// Save selected role to session
  Future<void> saveSelectedRole(String roleId, String roleName) async {
    final storage = _ref.read(storageServiceProvider);
    await storage.setSession("role_id", roleId);
    await storage.setSession("role_name", roleName);
    debugPrint("[AuthRepository] Saved role: $roleId -> $roleName");
  }

  /// Get remembered mobile from local storage
  String getRememberedMobile() {
    final storage = _ref.read(storageServiceProvider);
    return storage.getFromLocalStorage("LOGGED_IN_MOBILE");
  }

  /// Save or clear remembered mobile
  Future<void> setRememberMobile(String mobile, bool remember) async {
    final storage = _ref.read(storageServiceProvider);
    await storage.setLocalStorage("LOGGED_IN_MOBILE", remember ? mobile : "");
    debugPrint("[AuthRepository] Remember mobile: $remember");
  }

  /// Reload storage caches after login
  Future<void> reloadStorageCaches() async {
    final storage = _ref.read(storageServiceProvider);
    await storage.reloadCaches();
  }

  /// Write login log entry
  Future<void> writeLoginLog() async {
    try {
      final storage = _ref.read(storageServiceProvider);
      final dbHandler = _ref.read(dbHandlerProvider);

      final login = {
        '_id': 'hc:${Util.getDateForId()}_${Util.uuidv4()}',
        'date': Util.getTodayWithTime(),
        'type': Settings.type,
        'version': Settings.version,
        'emp_id': storage.getFromSession('logged_in_emp_id'),
        'emp_name': storage.getFromSession('logged_in_emp_name'),
        'mobile': storage.getFromSession('logged_in_mobile'),
        'center': storage.getFromSession('logged_in_tenant_name'),
        'department': storage.getFromSession('department_name'),
        'role_name': storage.getFromSession('role_name'),
        'region': storage.getFromSession('default_region'),
        'state': storage.getFromSession('default_state'),
        'last_updated_at': Util.getTimeStamp(),
      };

      await dbHandler.putDocument(
        'login_log',
        login['_id'] ?? '',
        login,
      );

      debugPrint('[AuthRepository] Login log queued: ${login['_id']}');
    } catch (e) {
      debugPrint('[AuthRepository] Error writing login log: $e');
    }
  }
}

/// Provider for AuthRepository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final postgresService = ref.read(postgresServiceProvider);
  return AuthRepository(postgresService, ref);
});
