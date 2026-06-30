import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:anderson_crm_flutter/features/users/data/user_model.dart';
import 'package:anderson_crm_flutter/features/users/data/users_repository.dart';

List<User> parseUsers(List<dynamic> rawData) {
  final List<User> users = [];

  for (final item in rawData) {
    List<dynamic> allocAreas = [];
    if (item['technician_allocated_areas'] != null &&
        item['technician_allocated_areas'] is List &&
        (item['technician_allocated_areas'] as List).isNotEmpty) {
      final techAllocAreas = item['technician_allocated_areas'][0];
      if (techAllocAreas != null && techAllocAreas['allocated_areas'] != null) {
        final allocatedAreasStr = techAllocAreas['allocated_areas'];
        if (allocatedAreasStr.toString().isNotEmpty) {
          try {
            allocAreas = allocatedAreasStr is String
                ? jsonDecode(allocatedAreasStr)
                : (allocatedAreasStr is List ? allocatedAreasStr : []);
          } catch (e) {
            debugPrint('Error parsing allocated areas: $e');
            allocAreas = [];
          }
        }
      }
    }

    String idCard = '';
    String idCardLocation = '';
    if (item['photo_id_card'] != null &&
        item['photo_id_card'].toString().isNotEmpty) {
      idCardLocation = item['photo_id_card'].toString();
      idCard = idCardLocation;
      if (idCard.contains('/')) {
        idCard = idCard.substring(idCard.lastIndexOf('/') + 1);
      }
    }

    dynamic roleId;
    String roleName = '';
    dynamic employeeActivities = item['employee_activities'];
    if (employeeActivities != null && employeeActivities is String) {
      try {
        employeeActivities = jsonDecode(employeeActivities);
      } catch (e) {
        debugPrint('Error parsing employee_activities: $e');
        employeeActivities = null;
      }
    }

    if (employeeActivities != null &&
        employeeActivities is Map &&
        employeeActivities['role_list'] != null &&
        (employeeActivities['role_list'] is List) &&
        (employeeActivities['role_list'] as List).isNotEmpty) {
      roleId = employeeActivities['role_list'];
    } else if (item['role_master'] != null) {
      roleId = item['role_master']['role_id'];
      roleName = item['role_master']['role_name'] ?? '';
    }

    users.add(User(
      empId: item['emp_id']?.toString() ?? '',
      id: item['emp_id']?.toString() ?? '',
      name: '${item['first_name'] ?? ''} ${item['last_name'] ?? ''}'.trim(),
      firstName: item['first_name'] ?? '',
      lastName: item['last_name'] ?? '',
      mobile: item['mobile'] ?? '',
      roleId: roleId,
      roleName: roleName, // Might be empty, filled later
      departmentId: item['department_list']?['department_id']?.toString() ?? '',
      departmentName: item['department_list']?['department_name'] ?? '',
      photoIdCard: idCard,
      idCardLocation: idCardLocation,
      allocatedAreas: allocAreas,
    ));
  }
  return users;
}

class UsersService {
  final UsersRepository _repository;

  UsersService(this._repository);

  Future<List<User>> getUsers({
    int page = 1,
    int rowsPerPage = 50,
    String? searchQuery,
  }) async {
    final offset = (page - 1) * rowsPerPage;
    final response = await _repository.fetchUsers(
      limit: rowsPerPage,
      offset: offset,
      searchQuery: searchQuery,
    );

    if (response is List) {
      List<User> users = await compute(parseUsers, response);
      final Set<String> allRoleIds = {};
      for (final user in users) {
        if (user.roleName.isEmpty && user.roleId is List) {
          for (final id in user.roleId) {
            allRoleIds.add(id.toString());
          }
        }
      }
      if (allRoleIds.isNotEmpty) {
        final roleMap = await _repository.getRoleNamesMap(allRoleIds);

        for (var i = 0; i < users.length; i++) {
          final user = users[i];
          if (user.roleName.isEmpty && user.roleId is List) {
            final resolvedNames = (user.roleId as List)
                .map((id) => roleMap[id.toString()])
                .where((name) => name != null)
                .join(', ');
            if (resolvedNames.isNotEmpty) {
              users[i] = user.copyWith(roleName: resolvedNames);
            }
          }
        }
      }

      return users;
    }
    return [];
  }

  Future<bool> deleteUser(String empId) async {
    return await _repository.deleteUser(empId);
  }

  Future<Map<String, dynamic>> addUser(Map<String, dynamic> doc,
      {bool isTechnician = false,
      List<Map<String, dynamic>>? allocatedAreas}) async {
    try {
      final result = await _repository.addUser(doc);

      if (result['statusCode'] == 201) {
        final searchResult = await _repository.searchEmployee(doc['mobile']);

        if (searchResult is List &&
            searchResult.isNotEmpty &&
            searchResult[0]['emp_id'] != null) {
          final empId = searchResult[0]['emp_id'].toString();

          if (isTechnician && allocatedAreas != null) {
            final allocDoc = {
              'emp_id': empId,
              'allocated_areas': jsonEncode(allocatedAreas),
              'created_by': doc['created_by'],
              'last_updated_by': doc['last_updated_by'],
            };
            await _repository.upsertAllocatedAreas(empId, allocDoc);
          }
        }
        return {'success': true};
      } else {
        return {
          'success': false,
          'message': 'Problem while adding new record.'
        };
      }
    } catch (e) {
      if (e.toString().contains('409')) {
        return {
          'success': false,
          'message':
              'Mobile number found in deleted user. Please contact Admin.'
        };
      }
      return {
        'success': false,
        'message': 'Problem while adding new record: $e'
      };
    }
  }

  Future<Map<String, dynamic>> updateUser(
      String empId, Map<String, dynamic> doc,
      {bool isTechnician = false,
      List<Map<String, dynamic>>? allocatedAreas}) async {
    try {
      final result = await _repository.updateUser(empId, doc);
      dynamic statusCode;
      try {
        statusCode = result['statusCode']; // If it's a map
      } catch (_) {
        try {
          statusCode = (result as dynamic).statusCode; // If it's an object
        } catch (e) {
          statusCode = 200; // Fallback or error?
        }
      }

      if (statusCode == 200 || statusCode == 204) {
        if (isTechnician && allocatedAreas != null) {
          final allocDoc = {
            'emp_id': empId,
            'allocated_areas': jsonEncode(allocatedAreas),
            'created_by': doc['created_by'],
            'last_updated_by': doc['last_updated_by'],
          };
          await _repository.upsertAllocatedAreas(empId, allocDoc);
        }
        return {'success': true};
      } else {
        return {'success': false, 'message': 'Problem in updation'};
      }
    } catch (e) {
      if (e.toString().contains('409')) {
        return {
          'success': false,
          'message':
              'Mobile number found in deleted user. Please contact Admin.'
        };
      }
      return {'success': false, 'message': 'Problem in updation: $e'};
    }
  }
}
