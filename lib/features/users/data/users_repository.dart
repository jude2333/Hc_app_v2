import 'package:anderson_crm_flutter/services/postgresService.dart';

class UsersRepository {
  final PostgresService _dbService;

  UsersRepository(this._dbService);

  Future<dynamic> fetchUsers({
    int limit = 50,
    int offset = 0,
    String? searchQuery,
  }) async {
    return await _dbService.getAllUsers(
      limit == -1 ? 10000 : limit,
      offset,
      searchQuery,
    );
  }

  Future<String?> fetchRoleName(dynamic roleId) async {
    if (roleId is List && roleId.isNotEmpty) {
      return await _dbService.getRoleNamesByIds(roleId);
    } else if (roleId is String) {
      return null;
    }
    return null;
  }

  Future<String> getRoleNameByIds(dynamic roleIds) async {
    return await _dbService.getRoleNamesByIds(roleIds) ?? '';
  }

  Future<Map<String, String>> getRoleNamesMap(Set<String> roleIds) async {
    return await _dbService.getRoleNamesMap(roleIds);
  }

  Future<bool> deleteUser(String empId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return true;
  }

  Future<Map<String, dynamic>> addUser(Map<String, dynamic> doc) async {
    final response = await _dbService.insertUser(doc);
    if (response is Map) {
      return response as Map<String, dynamic>;
    }
    try {
      final statusCode = response.statusCode;
      return {'statusCode': statusCode, 'data': response.data};
    } catch (e) {
      return {'statusCode': null, 'error': e.toString()};
    }
  }

  Future<dynamic> searchEmployee(String mobile) async {
    return await _dbService.searchEmployee(mobile);
  }

  Future<void> upsertAllocatedAreas(
      String empId, Map<String, dynamic> doc) async {
    await _dbService.upsertAllocatedAreas(empId, doc);
  }

  Future<Map<String, dynamic>> updateUser(
      String empId, Map<String, dynamic> doc) async {
    final response = await _dbService.updateUser(empId, doc);
    if (response is Map) {
      return response as Map<String, dynamic>;
    }
    try {
      final statusCode = response.statusCode;
      return {'statusCode': statusCode, 'data': response.data};
    } catch (e) {
      return {'statusCode': null, 'error': e.toString()};
    }
  }
}
