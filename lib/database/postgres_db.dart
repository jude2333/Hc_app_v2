import 'dart:convert';
import 'package:anderson_crm_flutter/util.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../config/settings.dart';
import 'package:flutter/widgets.dart';
import 'package:anderson_crm_flutter/repositories/storage_repository.dart';
import 'package:anderson_crm_flutter/config/settings.dart';

class PostgresDB {
  final StorageRepository _storage;
  final void Function(String)? onStatusChange;
  final void Function(String)? onWorkOrderChange;
  final void Function(String)? onTodayChange;

  Dio? _client;
  String _token = "";

  PostgresDB(
    this._storage, {
    this.onStatusChange,
    this.onWorkOrderChange,
    this.onTodayChange,
  });

  // Future<void> _setup() async {
  //   if (_token.isEmpty) {
  //     _token = await _storage.getSessionItem("pg_admin") ?? "";
  //   }

  //   final options = BaseOptions(
  //     baseUrl: Settings.currentPostgresUrl,
  //     connectTimeout: const Duration(seconds: 30),
  //     receiveTimeout: const Duration(seconds: 30),
  //   );

  //   final headers = <String, String>{
  //     "Content-Type": "application/json",
  //     "Prefer":
  //         "count=estimated,resolution=merge-duplicates,return=representation",
  //   };

  //   if (_token.isNotEmpty) {
  //     headers["Authorization"] = "Bearer $_token";
  //   }

  //   _client = Dio(options)
  //     ..options.headers = headers
  //     ..options.validateStatus = (status) => status != null && status < 500;

  //   onStatusChange?.call('Ready');
  // }

  Future<void> _setup() async {
    if (Settings.development) {
      // LOCAL MODE → NO TOKEN
      _token = "";
    } else {
      // PRODUCTION MODE → USE SAVED TOKEN
      _token = await _storage.getSessionItem("pg_admin") ?? "";
    }

    final options = BaseOptions(
      baseUrl: Settings.currentPostgresUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    );

    final headers = <String, String>{
      "Content-Type": "application/json",
      "Prefer":
          "count=estimated,resolution=merge-duplicates,return=representation",
    };

    // ADD HEADER ONLY IN PRODUCTION
    if (_token.isNotEmpty && !Settings.development) {
      headers["Authorization"] = "Bearer $_token";
    }

    _client = Dio(options)
      ..options.headers = headers
      ..options.validateStatus = (status) => status != null && status < 500;

    Future.microtask(() => onStatusChange?.call('Ready'));
  }

  /// Special setup for login only - ALWAYS uses live URL regardless of development flag
  /// This ensures authentication happens against live server even in dev mode
  Future<void> _setupForLogin() async {
    final options = BaseOptions(
      baseUrl: Settings.loginPostgresUrl, // Always live URL!
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    );

    final headers = <String, String>{
      "Content-Type": "application/json",
      "Prefer":
          "count=estimated,resolution=merge-duplicates,return=representation",
    };

    _client = Dio(options)
      ..options.headers = headers
      ..options.validateStatus = (status) => status != null && status < 500;
  }

  /// Setup for login WITH token - still uses live URL
  /// Called after initial auth succeeds to add Bearer token for appLogin()
  Future<void> _setupForLoginWithToken() async {
    final options = BaseOptions(
      baseUrl: Settings.loginPostgresUrl, // Always live URL!
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    );

    final headers = <String, String>{
      "Content-Type": "application/json",
      "Prefer":
          "count=estimated,resolution=merge-duplicates,return=representation",
    };

    // Add token for authenticated calls
    if (_token.isNotEmpty) {
      headers["Authorization"] = "Bearer $_token";
    }

    _client = Dio(options)
      ..options.headers = headers
      ..options.validateStatus = (status) => status != null && status < 500;
  }

  Future<dynamic> refreshToken() async {
    await _setup();

    try {
      final response = await _client!.post("/rpc/refresh_token_v2");

      if (response.statusCode == 200 && response.data['token'] != null) {
        _token = response.data['token'];

        await _storage.saveSessionItem("pg_admin", _token);

        final calendar = DateTime.now().add(const Duration(hours: 10));
        final expTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(calendar);
        await _storage.saveSessionItem("exp_time", expTime);

        await _setup();

        return "OK";
      }
    } catch (e) {
      debugPrint("in refresh token: $e");
    }

    return "";
  }

  Future<dynamic> appLogin() async {
    try {
      final app = {"app_name": Settings.appUser, "password": Settings.appPass};
      final response = await _client!.post("/rpc/app_login", data: app);
      debugPrint(
          "in app login: ${response.statusCode} ${jsonEncode(response.data)}");
      if (response.statusCode == 200) {
        final appVersion = response.data['app_version']?.toString() ?? "";
        await _storage.saveSessionItem("APP_VERSION", appVersion);
        return response.statusCode.toString();
      }
    } catch (e) {
      debugPrint("in app login catch: $e");
    }
    await _storage.clearSession();
    return "NEW_APP";
  }

  Future<String> login(String mobile, String password) async {
    // Use login-specific setup (ALWAYS live URL)
    await _setupForLogin();

    final user = {"mobile": mobile, "password": password, "department_id": 64};

    try {
      final response = await _client!.post("/rpc/login_v4", data: user);
      debugPrint(
          "in login: ${response.statusCode} ${jsonEncode(response.data)}");

      if (response.statusCode == 200) {
        final fDate = Util.formatDate(
            response.headers['date']?.first ?? DateTime.now().toString());

        await _storage.saveSessionItem("server_time", fDate);

        if (response.data['token'] != null) {
          _token = response.data['token'];
          await _storage.saveSessionItem("pg_admin", _token);

          final calendar = DateTime.now().add(const Duration(hours: 10));
          final expTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(calendar);
          await _storage.saveSessionItem("exp_time", expTime);

          // After login, re-setup with token but still use LIVE URL
          // This ensures appLogin() goes to live server too
          await _setupForLoginWithToken();
        }

        final appLoginResult = await appLogin();
        if (appLoginResult == "NEW_APP") {
          return "NEW_APP";
        }

        final tenantId = response.data['tenant_id'];
        final firstName = response.data['first'];
        final lastName = response.data['last'];
        final name = "$firstName $lastName";
        final empId = response.data['emp_id'];

        final userDetails = await getUserDetails(empId.toString());
        await _storage.saveSessionItem(
            "department_name", userDetails['department_name']);
        await _storage.saveSessionItem(
            "department_id", userDetails['department_id'].toString());

        final employeeActivities = response.data['employee_activities'];

        if (employeeActivities != null &&
            employeeActivities['role_list'] != null) {
          List<dynamic> roleList = employeeActivities['role_list'];
          List<String> roleListStr =
              roleList.map((role) => role.toString()).toList();

          await _storage.saveSessionItem("role_list", roleListStr.join(','));

          const checkRoleList = ['170', '120', '240', '250', '280', '270'];
          await _storage.saveSessionItem(
              "check_role_list", checkRoleList.join(','));

          List<String> finalRole = roleListStr
              .where((role) => checkRoleList.contains(role))
              .toList();

          if (finalRole.contains('170') && finalRole.contains('120')) {
            finalRole.remove('120');
          }

          if (finalRole.isEmpty) {
            if (checkRoleList.contains(userDetails['role_id'].toString())) {
              finalRole = [userDetails['role_id'].toString()];
            } else {
              return "NO_MATCHES";
            }
          }

          await _storage.saveSessionItem("final_role", finalRole.join(','));
        } else {
          const checkRoleList = ['170', '120', '240', '250', '280', '270'];
          await _storage.saveSessionItem("role_list", "");

          if (checkRoleList.contains(userDetails['role_id'].toString())) {
            await _storage.saveSessionItem(
                "final_role", userDetails['role_id'].toString());
          } else {
            return "NO_MATCHES";
          }
        }

        final initials = Util.getInitials(firstName, lastName);
        await _storage.saveSessionItem("logged_in_mobile", mobile);
        await _storage.saveSessionItem(
            "logged_in_tenant_id", tenantId.toString());
        await _storage.saveSessionItem("logged_in_emp_id", empId.toString());
        await _storage.saveSessionItem("logged_in_emp_name", name);
        await _storage.saveSessionItem("initials", initials);

        final tenant = await getTenantName(tenantId.toString());
        await _storage.saveSessionItem(
            "logged_in_tenant_name", tenant['tenant_name']);
        await _storage.saveSessionItem(
            "default_tenant_id", tenant['tenant_id'].toString());
        await _storage.saveSessionItem(
            "default_tenant_name", tenant['tenant_name']);
        await _storage.saveSessionItem("default_region", tenant['region']);
        await _storage.saveSessionItem("default_state", tenant['state']);
        await _storage.saveSessionItem("doc_dbs", tenant['doc_dbs']);

        if (!Settings.production) {
          await _storage.saveSessionItem(
              "doc_dbs", "chennai99_work_orders,chennai8_hc_notifications");
        }

        await _storage.saveSessionItem("del_doc_dbs", tenant['del_doc_dbs']);

        final dashboardTenantName = getDashboardTenantName(tenant['doc_dbs']);
        await _storage.saveSessionItem(
            "dashboard_tenant_name", dashboardTenantName ?? "");

        onStatusChange?.call('Logged in');
        onWorkOrderChange?.call('');
        onTodayChange?.call(Util.getTodayString());

        return response.statusCode.toString();
      }
    } catch (e) {
      debugPrint("in login catch: $e");
      onStatusChange?.call('Login failed');
    }

    return "Error";
  }

  String? getDashboardTenantName(String? str) {
    try {
      if (str != null && str.isNotEmpty) {
        if (str.contains("_")) {
          final tenant = str.substring(0, str.indexOf("_")).toLowerCase();
          if (tenant.startsWith("chennai")) {
            return "chennai";
          } else {
            return tenant;
          }
        }
      }
    } catch (e) {
      debugPrint("error in getDashboardTenantName: $e");
    }
    return null;
  }

  Future<dynamic> getUserWithMobile(String mobile) async {
    if (_client == null) {
      await _setup();
    }

    try {
      final response =
          await _client!.get("/employees?select=*&mobile=eq.$mobile");

      if (response.statusCode == 200 || response.statusCode == 206) {
        return response.data;
      } else if (response.statusCode == 401) {
        return "Error";
      }
    } catch (e) {
      debugPrint("error: $e");
    }

    return "Error";
  }

  Future<dynamic> insertUser(Map<String, dynamic> emp) async {
    onStatusChange?.call('Creating user');

    if (_client == null) {
      await _setup();
    }

    try {
      final response = await _client!.post("/employees", data: emp);

      onStatusChange?.call('User created successfully');
      return response;
    } catch (e) {
      debugPrint("error: $e");
      onStatusChange?.call('Failed to create user');
      return e.toString();
    }
  }

  Future<dynamic> updateUser(String empId, Map<String, dynamic> emp) async {
    onStatusChange?.call('Updating user');

    if (_client == null) {
      await _setup();
    }

    try {
      final response =
          await _client!.patch("/employees?emp_id=eq.$empId", data: emp);

      onStatusChange?.call('User updated successfully');
      return response;
    } catch (e) {
      debugPrint("error: $e");
      onStatusChange?.call('Failed to update user');
      return e.toString();
    }
  }

  Future<dynamic> upsertAllocatedAreas(
      String empId, Map<String, dynamic> areas) async {
    onStatusChange?.call('Updating allocated areas');

    if (_client == null) {
      await _setup();
    }

    try {
      final response = await _client!
          .get("/technician_allocated_areas?select=taa_id&emp_id=eq.$empId");

      if (response.data.length == 0) {
        onStatusChange?.call('Creating new allocated areas');
        return await _client!.post("/technician_allocated_areas", data: areas);
      } else {
        onStatusChange?.call('Updating existing allocated areas');
        final taaId = response.data[0]['taa_id'];
        return await _client!
            .patch("/technician_allocated_areas?taa_id=eq.$taaId", data: areas);
      }
    } catch (e) {
      debugPrint("error: $e");
      onStatusChange?.call('Failed to update allocated areas');
      return e.toString();
    }
  }

  Future<dynamic> getRoleList([String? search]) async {
    debugPrint("in get role list: $search");
    if (_client == null) {
      await _setup();
    }

    try {
      Response response;
      if (search != null && search.isNotEmpty) {
        response = await _client!.get(
            "/role_master?select=role_id,role_name&role_name=ilike.*$search*");
      } else {
        response = await _client!.get("/role_master?select=role_id,role_name");
      }

      if (response.statusCode == 200 || response.statusCode == 206) {
        return response.data;
      } else if (response.statusCode == 401) {
        onStatusChange?.call('Session expired');
        return "Error";
      }
    } catch (e) {
      debugPrint("error: $e");
    }

    return "Error";
  }

  Future<dynamic> getDeptList([String? search]) async {
    if (_client == null) {
      await _setup();
    }

    try {
      Response response;
      if (search != null && search.isNotEmpty) {
        response = await _client!.get(
            "/department_list?select=department_id,department_name&department_name=ilike.*$search*");
      } else {
        response = await _client!
            .get("/department_list?select=department_id,department_name");
      }

      if (response.statusCode == 200 || response.statusCode == 206) {
        return response.data;
      } else if (response.statusCode == 401) {
        return "Error";
      }
    } catch (e) {
      debugPrint("error: $e");
    }

    return "Error";
  }

  Future<dynamic> getTenantList([String? search]) async {
    if (_client == null) {
      await _setup();
    }

    try {
      Response response;
      if (search != null && search.isNotEmpty) {
        response = await _client!.get(
            "/tenant_master?select=tenant_id,tenant_name,region,state&tenant_name=ilike.*$search*");
      } else {
        response = await _client!
            .get("/tenant_master?select=tenant_id,tenant_name,region,state");
      }

      if (response.statusCode == 200 || response.statusCode == 206) {
        return response.data;
      } else if (response.statusCode == 401) {
        return "Error";
      }
    } catch (e) {
      debugPrint("error: $e");
    }

    return "Error";
  }

  Future<dynamic> getAssignedTenantList([
    String? search,
  ]) async {
    if (_client == null) await _setup();
    final empId = await _storage.getSessionItem("logged_in_emp_id");

    try {
      final response = (search?.isNotEmpty ?? false)
          ? await _client!.get(
              "/emp_tenant_mapping?select=*,tenant_master(tenant_id,tenant_name,region,state)&emp_id=eq.$empId&tenant_master.tenant_name=ilike.*$search*")
          : await _client!.get(
              "/emp_tenant_mapping?select=*,tenant_master(tenant_id,tenant_name,region,state)&emp_id=eq.$empId");

      if (response.statusCode == 200 || response.statusCode == 206) {
        final list = response.data as List;
        final retArray = <Map<String, dynamic>>[];

        retArray.add({
          "tenant_id": await _storage.getSessionItem("default_tenant_id"),
          "tenant_name": await _storage.getSessionItem("default_tenant_name"),
          "region": await _storage.getSessionItem("default_region"),
          "state": await _storage.getSessionItem("default_state"),
        });

        for (final item in list) {
          if (item['tenant_master'] != null) {
            retArray.add(Map<String, dynamic>.from(item['tenant_master']));
          }
        }
        return retArray;
      } else if (response.statusCode == 401) {
        await _setup();
        return getAssignedTenantList(search);
      } else {
        return "Error";
      }
    } catch (e) {
      debugPrint("getAssignedTenantList error: $e");
      return "Error";
    }
  }

  Future<dynamic> getTenantName(String tenantId) async {
    if (_client == null) {
      await _setup();
    }

    try {
      final response = await _client!.get(
          "/tenant_master?select=tenant_id,tenant_name,region,state,doc_dbs,del_doc_dbs&tenant_id=eq.$tenantId");

      if (response.statusCode == 200 || response.statusCode == 206) {
        debugPrint("tenant master: ${jsonEncode(response.data)}");
        return response.data[0];
      }
    } catch (e) {
      debugPrint("error: $e");
    }

    return "Error";
  }

  Future<dynamic> changeTenant(String modId) async {
    if (_client == null) await _setup();
    final tenant = {"tenant_id": modId};

    try {
      final response = await _client!.post("/rpc/change_tenant", data: tenant);
      debugPrint("in change tenant: $response ${jsonEncode(response.data)}");

      if (response.statusCode == 200) {
        if (response.data['token'] != null) {
          _token = response.data['token'];
          await _storage.saveSessionItem("pg_admin", _token);

          final calendar = DateTime.now().add(const Duration(hours: 10));
          final expTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(calendar);
          await _storage.saveSessionItem("exp_time", expTime);
          await _setup();
        }

        final tenantId = response.data['tenant_id'];
        final firstName = response.data['first'];
        final lastName = response.data['last'];
        final name = "$firstName $lastName";
        final empId = response.data['emp_id'];
        final mobile = response.data['mobile'];
        final initials = Util.getInitials(firstName, lastName);

        await _storage.saveSessionItem("logged_in_mobile", mobile);
        await _storage.saveSessionItem("logged_in_tenant_id", tenantId);
        await _storage.saveSessionItem("logged_in_emp_id", empId);
        await _storage.saveSessionItem("logged_in_emp_name", name);
        await _storage.saveSessionItem("initials", initials);

        final tenantData = await getTenantName(tenantId);
        await _storage.saveSessionItem(
            "logged_in_tenant_name", tenantData['tenant_name']);

        await _storage.saveSessionItem("doc_dbs", tenantData['doc_dbs'] ?? "");
        await _storage.saveSessionItem(
            "del_doc_dbs", tenantData['del_doc_dbs'] ?? "");

        final dashboardName =
            getDashboardTenantName(tenantData['doc_dbs'] ?? "");
        await _storage.saveSessionItem(
            "dashboard_tenant_name", dashboardName ?? "");

        return response.statusCode;
      }
      return response;
    } catch (e) {
      debugPrint("in change center: $e");
      return e.toString();
    }
  }

  Future<dynamic> getUserDetails(String empId) async {
    if (_client == null) {
      await _setup();
    }

    try {
      final response = await _client!.get(
          "/employees?select=*,department_list(department_id,department_name),role_master(role_id,role_name),technician_allocated_areas(allocated_areas)&emp_id=eq.$empId");

      if (response.statusCode == 200 || response.statusCode == 206) {
        final item = response.data[0];
        debugPrint("user details: ${jsonEncode(item)}");
        var allocAreas = <dynamic>[];

        if (Util.isNotEmpty(item['technician_allocated_areas'])) {
          final str = item['technician_allocated_areas'][0]['allocated_areas'];
          allocAreas = jsonDecode(str);
        }

        String idCard = "";
        if (item['photo_id_card'] != null) {
          idCard = item['photo_id_card'];
          if (idCard.contains("/")) {
            idCard = idCard.substring(idCard.lastIndexOf("/") + 1);
          }
        }

        final result = Map<String, dynamic>.from(item);
        result['password'] = null;
        result['_id'] = item['emp_id'];
        result['name'] = "${item['first_name']} ${item['last_name']}";
        result['role_id'] = item['role_master']['role_id'];
        result['role_name'] = item['role_master']['role_name'];
        result['department_id'] = item['department_list']['department_id'];
        result['department_name'] = item['department_list']['department_name'];
        result['allocated_areas'] = allocAreas;
        result['id_card_location'] = item['photo_id_card'];
        result['photo_id_card'] = idCard;

        return result;
      } else if (response.statusCode == 401) {
        return "Error";
      }
    } catch (e) {
      debugPrint("error: $e");
    }

    return "Error";
  }

  Future<dynamic> getAllClients() async {
    onStatusChange?.call('Loading clients');

    if (_client == null) {
      await _setup();
    }

    try {
      final response = await _client!.get(
          "/doctor_login?select=*,client_master(client_type,client_name)&order=last_updated_at.desc");

      if (response.statusCode == 200 || response.statusCode == 206) {
        final list = response.data;
        debugPrint(list);
        final retArray = <Map<String, dynamic>>[];

        for (final item in list) {
          final result = Map<String, dynamic>.from(item);
          result['name'] = "${item['first_name']} ${item['last_name']}";
          result['client_name'] = item['client_master']['client_name'];
          result['client_type'] = item['client_master']['client_type'];
          retArray.add(result);
        }
        onStatusChange?.call('Clients loaded successfully');

        return retArray;
      } else if (response.statusCode == 401) {
        onStatusChange?.call('Session expired');

        return "Error";
      }
    } catch (e) {
      debugPrint("error: $e");
      onStatusChange?.call('Failed to load clients');
    }

    return "Error";
  }

  Future<dynamic> getAllUsers(int itemsPerPage, int offset,
      [String? search]) async {
    Future.microtask(() => onStatusChange?.call('Loading users'));

    // if (_client == null) {
    //   await _setup();
    // }

    if (_client == null ||
        _client!.options.baseUrl != Settings.currentPostgresUrl) {
      await _setup();
    }

    try {
      Response response;
      if (search != null && search.isNotEmpty) {
        response = await _client!.get(
            "/employees?select=*,department_list(department_id,department_name),role_master(role_id,role_name),technician_allocated_areas(allocated_areas)&department_id=eq.64&or=(first_name.ilike.*$search*,last_name.ilike.*$search*,mobile.ilike.*$search*)&limit=$itemsPerPage&offset=$offset&order=last_updated_at.desc");
      } else {
        response = await _client!.get(
            "/employees?select=*,department_list(department_id,department_name),role_master(role_id,role_name),technician_allocated_areas(allocated_areas)&department_id=eq.64&limit=$itemsPerPage&offset=$offset&order=last_updated_at.desc");
      }

      onStatusChange?.call('Users loaded successfully');
      if (response.statusCode == 200 || response.statusCode == 206) {
        final list = response.data;
        final retArray = <Map<String, dynamic>>[];
        for (final item in list) {
          final result = Map<String, dynamic>.from(item);

          retArray.add(result);
        }
        return retArray;
      }
    } catch (e) {
      debugPrint("error: $e");

      onStatusChange?.call('Failed to load users');
      return e.toString();
    }
  }

  Future<dynamic> deleteUser(String empId) async {
    onStatusChange?.call('Deleting user');

    if (_client == null) {
      await _setup();
    }

    final emp = {"emp_id": empId};

    try {
      final response = await _client!.post("/rpc/delete_employee", data: emp);
      debugPrint("deletion: ${jsonEncode(response)}");

      onStatusChange?.call('User deleted successfully');
      return response;
    } catch (e) {
      debugPrint("error: $e");

      onStatusChange?.call('Failed to delete user');
      return e;
    }
  }

  Future<dynamic> getTechnicians([String? search]) async {
    if (_client == null) {
      await _setup();
    }

    final tenantId = await _storage.getSessionItem("logged_in_tenant_id");

    try {
      Response response;

      if (search != null && search.isNotEmpty) {
        response = await _client!.get(
            "/employees?select=*,department_list(department_id,department_name),role_master(role_id,role_name),technician_allocated_areas(allocated_areas)&default_tenant_id=eq.$tenantId&department_id=eq.64&role_id=eq.240&or=(first_name.ilike.*$search*,last_name.ilike.*$search*,mobile.ilike.*$search*)&order=last_updated_at.desc");
      } else {
        response = await _client!.get(
            "/employees?select=*,department_list(department_id,department_name),role_master(role_id,role_name),technician_allocated_areas(allocated_areas)&default_tenant_id=eq.$tenantId&department_id=eq.64&role_id=eq.240&order=last_updated_at.desc");
      }

      if (response.statusCode == 200 || response.statusCode == 206) {
        final list = response.data;
        final retArray = <Map<String, dynamic>>[];

        for (final item in list) {
          var allocAreas = <dynamic>[];

          if (Util.isNotEmpty(item['technician_allocated_areas'])) {
            final str =
                item['technician_allocated_areas'][0]['allocated_areas'];
            allocAreas = jsonDecode(str);
          }

          String idCard = "";
          if (item['photo_id_card'] != null) {
            idCard = item['photo_id_card'];
            if (idCard.contains("/")) {
              idCard = idCard.substring(idCard.lastIndexOf("/") + 1);
            }
          }

          if (item['department_list']['department_name'] == "HOME COLLECTION" &&
              item['role_master']['role_name'] == "TECHNICIAN") {
            final result = Map<String, dynamic>.from(item);
            result['password'] = null;
            result['_id'] = item['emp_id'];
            result['name'] = "${item['first_name']} ${item['last_name']}";
            result['mobile'] = item['mobile'];
            result['role_id'] = item['role_master']['role_id'];
            result['role_name'] = item['role_master']['role_name'];
            result['department_id'] = item['department_list']['department_id'];
            result['department_name'] =
                item['department_list']['department_name'];
            result['allocated_areas'] = allocAreas;
            result['id_card_location'] = item['photo_id_card'];
            result['photo_id_card'] = idCard;
            retArray.add(result);
          }
        }

        debugPrint("technicians here: ${retArray.length}");
        return retArray;
      } else if (response.statusCode == 401) {
        return "Error";
      }
    } catch (e) {
      debugPrint("error: $e");

      return "Error";
    }
  }

  Future<dynamic> getB2BClients() async {
    onStatusChange?.call('Loading B2B clients');

    if (_client == null) {
      await _setup();
    }

    try {
      final response = await _client!.get(
          "/doctor_login?select=*,client_master(client_id,client_type,client_name)");

      if (response.statusCode == 200 || response.statusCode == 206) {
        debugPrint("doctor_login: ${jsonEncode(response.data)}");

        onStatusChange?.call('B2B clients loaded successfully');
        return response.data;
      } else if (response.statusCode == 401) {
        onStatusChange?.call('Session expired');
        return "Error";
      }
    } catch (e) {
      debugPrint("error: $e");

      onStatusChange?.call('Failed to load B2B clients');
    }

    return "Error";
  }

  Future<String?> getRoleNamesByIds(roleIds) async {
    if (_client == null) {
      await _setup();
    }

    try {
      List<String> roleIdArray = [];

      if (roleIds is List) {
        roleIdArray = List<String>.from(roleIds);
      } else if (roleIds is String) {
        roleIdArray = roleIds.split(',');
      } else {
        throw Exception('Invalid role_ids format');
      }

      if (roleIdArray.isEmpty) {
        throw Exception('No role_ids provided');
      }

      final query =
          "/role_master?select=role_name&role_id=in.(${roleIdArray.join(',')})";

      final response = await _client!.get(query);

      if (response.data != null && response.data.isNotEmpty) {
        final roleNames = response.data
            .map<String>((item) => item['role_name'].toString())
            .toList();
        return roleNames.join(', ');
      } else {
        throw Exception('Roles not found');
      }
    } catch (e) {
      debugPrint('Error fetching role names by role_ids: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> searchPatients(
      String str, String mode) async {
    if (_client == null) await _setup();

    String query;
    switch (mode) {
      case 'Mobile':
        query =
            '/hc_patient_master?select=*,hc_patient_visit_detail(doc)&mobile_number=eq.$str';
        break;
      case 'Date':
        query = '/hc_patient_visit_detail?select=doc&visit_date=eq.$str';
        break;
      case 'Name':
        query =
            '/hc_patient_visit_detail?select=doc&patient_name=ilike.${str.toLowerCase().trim()}*&order=visit_date.desc';
        break;
      default:
        return [];
    }

    try {
      final res = await _client!.get(query);
      if (res.statusCode != 200 && res.statusCode != 206) return [];

      final body = res.data;
      List<Map<String, dynamic>> processedResults = [];

      debugPrint('Raw API response type: ${body.runtimeType}');

      if (mode == 'Mobile') {
        if (body is Map && body['data'] is List) {
          for (var masterRecord in body['data'] as List) {
            if (masterRecord is Map<String, dynamic>) {
              final visitDetails = masterRecord['hc_patient_visit_detail'];
              if (visitDetails is List) {
                for (var visit in visitDetails) {
                  if (visit is Map<String, dynamic>) {
                    final doc = visit['doc'];
                    final extractedData = _extractWorkOrderData(doc);
                    if (extractedData.isNotEmpty) {
                      processedResults.add(extractedData);
                    }
                  }
                }
              }
            }
          }
        }
      } else {
        List<dynamic> dataList = [];
        if (body is Map && body['data'] is List) {
          dataList = body['data'] as List;
        } else if (body is List) {
          dataList = body;
        }

        for (var item in dataList) {
          if (item is Map<String, dynamic>) {
            final doc = item['doc'];
            final extractedData = _extractWorkOrderData(doc);
            if (extractedData.isNotEmpty) {
              processedResults.add(extractedData);
            }
          }
        }
      }

      debugPrint(
          'Processed ${processedResults.length} search results for $mode');
      if (processedResults.isNotEmpty) {
        debugPrint('First result keys: ${processedResults.first.keys}');
        debugPrint(
            'Sample - name: ${processedResults.first['name']}, mobile: ${processedResults.first['mobile']}');
      }

      return processedResults;
    } catch (e) {
      debugPrint('searchPatients error: $e');
      return [];
    }
  }

  Map<String, dynamic> _extractWorkOrderData(dynamic doc) {
    try {
      Map<String, dynamic> workOrderData = {};

      if (doc is String) {
        workOrderData = json.decode(doc) as Map<String, dynamic>;
      } else if (doc is Map<String, dynamic>) {
        workOrderData = Map<String, dynamic>.from(doc);
      } else {
        return {};
      }

      if (workOrderData['appointment_date'] != null &&
          workOrderData['appointment_time'] != null) {
        try {
          String appDtTime =
              "${workOrderData['appointment_date']} ${workOrderData['appointment_time']}";
          DateTime sortTime = _parseAppTime(appDtTime);
          workOrderData['sort_time'] = sortTime.millisecondsSinceEpoch;
        } catch (e) {
          debugPrint('Error parsing appointment time: $e');
          workOrderData['sort_time'] = 0;
        }
      } else {
        workOrderData['sort_time'] = 0;
      }

      return workOrderData;
    } catch (e) {
      debugPrint('Error extracting work order data: $e');
      return {};
    }
  }

  DateTime _parseAppTime(String appDtTime) {
    try {
      final parts = appDtTime.split(' ');
      if (parts.length == 2) {
        final dateParts = parts[0].split('-');
        final timeParts = parts[1].split(':');

        if (dateParts.length == 3 && timeParts.length >= 2) {
          return DateTime(
            int.parse(dateParts[2]),
            int.parse(dateParts[1]),
            int.parse(dateParts[0]),
            int.parse(timeParts[0]),
            int.parse(timeParts[1]),
          );
        }
      }
    } catch (e) {
      debugPrint('Error in _parseAppTime: $e');
    }
    return DateTime.now();
  }

  Future<dynamic> searchEmployee(String str) async {
    onStatusChange?.call('Searching employee');

    if (_client == null) {
      await _setup();
    }

    try {
      final response = await _client!.get("/employees?mobile=eq.$str");

      if (response.statusCode == 200 || response.statusCode == 206) {
        debugPrint('search_employees${jsonEncode(response.data)}');

        onStatusChange?.call('Employee found');
        return response.data;
      }
    } catch (e) {
      debugPrint("error: $e");

      onStatusChange?.call('Search failed');
      return e.toString();
    }

    return "Error";
  }

  Future<dynamic> getRoleName(String str) async {
    onStatusChange?.call('Loading role details');

    if (_client == null) {
      await _setup();
    }

    try {
      final response =
          await _client!.get("/role_master?select=role_name&role_id=eq.$str");

      if (response.statusCode == 200 || response.statusCode == 206) {
        debugPrint('search_employees${jsonEncode(response.data)}');

        onStatusChange?.call('Role details loaded');
        return response.data;
      }
    } catch (e) {
      debugPrint("error: $e");

      onStatusChange?.call('Failed to load role details');
      return e.toString();
    }

    return "Error";
  }
}
