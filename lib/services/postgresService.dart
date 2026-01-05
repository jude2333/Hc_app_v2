import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/postgres_db.dart';
import 'package:anderson_crm_flutter/providers/postgres_provider.dart';

class PostgresService {
  final PostgresDB _db;

  PostgresService(this._db);

  // Authentication methods
  Future<String> login(String mobile, String password) async {
    return await _db.login(mobile, password);
  }

  Future<dynamic> refreshToken() async {
    return await _db.refreshToken();
  }

  Future<dynamic> appLogin() async {
    return await _db.appLogin();
  }

  // User management methods
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

  // Role and department methods
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

  // Tenant management methods
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

  // Technician methods
  Future<dynamic> getTechnicians([String? search]) async {
    return await _db.getTechnicians(search);
  }

  Future<dynamic> upsertAllocatedAreas(
      String empId, Map<String, dynamic> areas) async {
    return await _db.upsertAllocatedAreas(empId, areas);
  }

  // Client methods
  Future<dynamic> getAllClients() async {
    return await _db.getAllClients();
  }

  Future<dynamic> getB2BClients() async {
    return await _db.getB2BClients();
  }

  // Patient search methods
  Future<dynamic> searchPatients(String str, String mode) async {
    return await _db.searchPatients(str, mode);
  }

  // Utility methods
  String? getDashboardTenantName(String? str) {
    return _db.getDashboardTenantName(str);
  }
}

// Provider for the database service
final postgresServiceProvider = Provider<PostgresService>((ref) {
  final db = ref.watch(postgresDbProvider);
  return PostgresService(db);
});
