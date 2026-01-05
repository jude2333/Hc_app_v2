import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PostgresRepository {
  static const String _baseUrl = 'https://api.andrsn.in';
  late Dio _dio;

  PostgresRepository() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));
  }

  Future<Map<String, dynamic>> login(String mobile, String password) async {
    final res = await _dio.post('/rpc/login_v4', data: {
      'mobile': mobile,
      'password': password,
      'department_id': 64,
    });
    return res.data;
  }

  Future<void> refreshToken() async {
    await _dio.post('/rpc/refresh_token_v2');
  }

  Future<List<dynamic>> getAllUsers({int limit = 20, int offset = 0, String? search}) async {
    final query = search != null
        ? '/employees?or=(first_name.ilike.*$search*,last_name.ilike.*$search*)&limit=$limit&offset=$offset'
        : '/employees?limit=$limit&offset=$offset';
    final res = await _dio.get(query);
    return res.data as List;
  }

  Future<Map<String, dynamic>> getUserDetails(int empId) async {
    final res = await _dio.get('/employees?emp_id=eq.$empId');
    return res.data.first;
  }

  Future<List<dynamic>> getAssignedTenantList(String search) async {
    final empId = await _loggedInEmpId();
    final query = search.isNotEmpty
        ? '/emp_tenant_mapping?select=*,tenant_master(*)&emp_id=eq.$empId&tenant_master.tenant_name=ilike.*$search*'
        : '/emp_tenant_mapping?select=*,tenant_master(*)&emp_id=eq.$empId';
    final res = await _dio.get(query);
    return res.data as List;
  }

  Future<List<dynamic>> getRoleList([String search = '']) async =>
      (await _dio.get('/role_master?select=role_id,role_name&role_name=ilike.*$search*')).data;

  Future<List<dynamic>> getDeptList([String search = '']) async =>
      (await _dio.get('/department_list?select=department_id,department_name&department_name=ilike.*$search*')).data;

  /* ---------- INTERNAL ---------- */
  static Future<String> _loggedInEmpId() async =>
      (await SharedPreferences.getInstance()).getString('logged_in_emp_id') ?? '0';
}