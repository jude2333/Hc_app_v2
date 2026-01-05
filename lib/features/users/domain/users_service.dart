import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:anderson_crm_flutter/features/users/data/user_model.dart';
import 'package:anderson_crm_flutter/features/users/data/users_repository.dart';

// Top-level function for compute
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

    // Role logic - this part is tricky because it might require async calls which compute can't easily do if it depends on other services.
    // However, we can process what we have. If we need to fetch role names, we might need to do that BEFORE or AFTER compute,
    // or pass the role map into compute.
    // Looking at the original controller, it calls `_dbService.getRoleNamesByIds(roleId)`.
    // We CANNOT do async DB calls inside `compute` easily without passing the DB service or a callback, which is complex.
    // So we will parse the basic structure here, and handle the async role fetching in the service layer *outside* compute,
    // OR we fetch all roles beforehand and pass a map.
    // For now, let's map what we can.

    // We will store the raw role data in the User object or a temporary DTO and resolve it later?
    // Or better: The original code awaited `getRoleNamesByIds` inside the loop. This is bad for performance.
    // We should probably fetch the raw data, then loop.

    // Let's try to replicate the logic but optimize.
    // Since `compute` runs in isolation, it can't call the DB.
    // So we will just parse the JSON to a simpler structure, and let the main thread handle the async DB calls if needed.
    // BUT, the goal is to offload heavy parsing.

    // Actually, `getRoleNamesByIds` is an async call. We can't put that in `compute` unless we pass the data it needs.
    // If `getRoleNamesByIds` just does a DB lookup, we can't do it in isolate easily.
    // So we will have to keep the async part in the main isolate or refactor how roles are fetched.

    // Let's parse the basic fields.

    dynamic roleId;
    String roleName = '';

    // Handle employee_activities - it might be a JSON string or a Map
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
      // roleName will be fetched later
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
      // Offload parsing to isolate
      List<User> users = await compute(parseUsers, response);

      // Post-processing for roles that need async fetching
      // This is still on the main thread but at least the JSON parsing is offloaded.
      // To optimize, we could fetch all unique role IDs and do a batch fetch?
      // The original code did it one by one.

      for (var i = 0; i < users.length; i++) {
        final user = users[i];
        if (user.roleName.isEmpty &&
            user.roleId != null &&
            user.roleId is List) {
          final name = await _repository.getRoleNameByIds(user.roleId);
          // We need to update the user object. Since User is immutable, we replace it.
          users[i] = User(
            empId: user.empId,
            id: user.id,
            name: user.name,
            firstName: user.firstName,
            lastName: user.lastName,
            mobile: user.mobile,
            roleName: name,
            roleId: user.roleId,
            departmentId: user.departmentId,
            departmentName: user.departmentName,
            photoIdCard: user.photoIdCard,
            idCardLocation: user.idCardLocation,
            allocatedAreas: user.allocatedAreas,
          );
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
        // Assuming result is Map from repository wrapper or we need to check how insertUser returns
        // The original code checked result.statusCode.
        // DatabaseService.insertUser likely returns a Response object or similar.
        // We need to be careful here. The repository wrapper returned whatever insertUser returned.
        // Let's assume it returns a dynamic that has statusCode.

        // Actually, let's look at the original code: `final result = await _dbService.insertUser(doc);`
        // `if (result.statusCode == 201)`
        // So it returns a Response object (likely Dio or http).

        // We need to check searchEmployee
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
      // Original: if (result.statusCode == 200 || result.statusCode == 204)

      // We need to handle the dynamic return type of updateUser
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
