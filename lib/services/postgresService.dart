import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/postgres_db.dart';
import 'package:anderson_crm_flutter/providers/postgres_provider.dart';

class PostgresService {
  final PostgresDB _db;

  PostgresService(this._db);

  Future<String> login(String mobile, String password) async {
    return await _db.login(mobile, password);
  }

  Future<dynamic> refreshToken() async {
    return await _db.refreshToken();
  }

  Future<dynamic> appLogin() async {
    return await _db.appLogin();
  }

  Future<dynamic> getUserWithMobile(String mobile) async {
    return await _db.getUserWithMobile(mobile);
  }

  Future<dynamic> insertUser(Map<String, dynamic> emp) async {
    return await _db.insertUser(emp);
  }

  Future<dynamic> updateUser(String empId, Map<String, dynamic> emp) async {
    return await _db.updateUser(empId, emp);
  }

  Future<dynamic> deleteUser(String empId) async {
    return await _db.deleteUser(empId);
  }

  Future<dynamic> getUserDetails(String empId) async {
    return await _db.getUserDetails(empId);
  }

  Future<dynamic> getAllUsers(int itemsPerPage, int offset,
      [String? search]) async {
    return await _db.getAllUsers(itemsPerPage, offset, search);
  }

  Future<dynamic> searchEmployee(String str) async {
    return await _db.searchEmployee(str);
  }

  Future<dynamic> getRoleList([String? search]) async {
    return await _db.getRoleList(search);
  }

  Future<dynamic> getRoleName(String roleId) async {
    return await _db.getRoleName(roleId);
  }

  Future<String?> getRoleNamesByIds(dynamic roleIds) async {
    return await _db.getRoleNamesByIds(roleIds);
  }

  Future<dynamic> getDeptList([String? search]) async {
    return await _db.getDeptList(search);
  }

  Future<dynamic> getTenantList([String? search]) async {
    return await _db.getTenantList(search);
  }

  Future<dynamic> getAssignedTenantList([String? search]) async {
    return await _db.getAssignedTenantList(search);
  }

  Future<dynamic> getTenantName(String tenantId) async {
    return await _db.getTenantName(tenantId);
  }

  Future<dynamic> changeTenant(String modId) async {
    return await _db.changeTenant(modId);
  }

  Future<dynamic> getTechnicians([String? search]) async {
    return await _db.getTechnicians(search);
  }

  Future<dynamic> upsertAllocatedAreas(
      String empId, Map<String, dynamic> areas) async {
    return await _db.upsertAllocatedAreas(empId, areas);
  }

  Future<Map<String, String>> getTechnicianById(String empId) async {
    try {
      final result = await _db.getUserDetails(empId);
      if (result != null && result != "Error") {
        return {
          'mobile': result['mobile']?.toString() ?? '',
          'id_card_location': result['id_card_location']?.toString() ?? '',
          'name': result['name']?.toString() ?? '',
        };
      }
    } catch (e) {
      // Error logged in PostgresDB
    }
    return {'mobile': '', 'id_card_location': '', 'name': ''};
  }

  Future<dynamic> toggleRemittance(
      String workOrderId, bool acceptRemittance, String user) async {
    return await _db.toggleRemittance(workOrderId, acceptRemittance, user);
  }

  Future<dynamic> getAllClients() async {
    return await _db.getAllClients();
  }

  Future<dynamic> getB2BClients() async {
    return await _db.getB2BClients();
  }

  Future<dynamic> searchPatients(String str, String mode) async {
    return await _db.searchPatients(str, mode);
  }

  String? getDashboardTenantName(String? str) {
    return _db.getDashboardTenantName(str);
  }

  /// Get all work orders for a specific date - queries PostgreSQL directly
  Future<List<Map<String, dynamic>>> getAllWorkOrdersForDate(
      String dateStr) async {
    return await _db.getAllWorkOrdersForDate(dateStr);
  }

  /// Get all work orders for a date range - queries PostgreSQL directly
  Future<List<Map<String, dynamic>>> getAllWorkOrdersForDateRange(
      String startDate, String endDate) async {
    return await _db.getAllWorkOrdersForDateRange(startDate, endDate);
  }
}

final postgresServiceProvider = Provider<PostgresService>((ref) {
  final db = ref.watch(postgresDbProvider);
  return PostgresService(db);
});
