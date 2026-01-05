import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:powersync/powersync.dart';
import 'package:jose/jose.dart';
import 'package:anderson_crm_flutter/services/storage_service.dart';
import '../../config/settings.dart';

class BackendConnector extends PowerSyncBackendConnector {
  final StorageService storage;

  // Platform-adaptive API URLs
  static String get apiUrl {
    if (kIsWeb) {
      return 'http://localhost:5000';
    } else {
      return 'http://10.0.2.2:5000';
    }
  }

  String get postgrestBaseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000';
    } else {
      return 'http://10.0.2.2:3000';
    }
  }

  final String powerSyncUrl = Settings.powerSyncUrl;

  BackendConnector({required this.storage}) {
    debugPrint('[BackendConnector] Initialized - PowerSync: $powerSyncUrl');
  }

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    debugPrint('[BackendConnector] fetchCredentials()');

    try {
      final token = await _getAuthToken();

      if (token == null) {
        debugPrint('[BackendConnector] Failed to get auth token');
        return null;
      }

      debugPrint('[BackendConnector] Token generated (${token.length} chars)');
      return PowerSyncCredentials(endpoint: powerSyncUrl, token: token);
    } catch (e) {
      debugPrint('[BackendConnector] fetchCredentials error: $e');
      return null;
    }
  }

  Future<String?> _getAuthToken() async {
    try {
      final empId = storage.getFromSession('logged_in_emp_id');
      final roleName = storage.getFromSession('role_name');
      final tenantId = storage.getFromSession('logged_in_tenant_id');

      if (empId.isEmpty || roleName.isEmpty || tenantId.isEmpty) {
        debugPrint('[BackendConnector] Missing session credentials');
        return null;
      }

      const privateKeyJwk = {
        "kty": "RSA",
        "n":
            "uIyEmd0HNaIqZXxFCXFNGxCH-pwH2D871IBlfdwuEGT2FoIjFlmgCWAWjFeHqy-FLddAy6q0AAMYQ3vsHMM6k4_14HalRy8byxQxEQK3Pq4Ua79zc4WLqQcDsCRfbEd5FD2O3NIk7nKHpJ3wKRk8fMcuMUfNEhNlEMfQzqTgiLUpG5CfDbfRGeBndG3pXF63iqZ1rZbVdkrMncCDkqS2MMxua7T98tdi_6nqYXQzCV-QFHRkOD7mx0K8zHYPR5psn1m_8xdIa_IJxYGo6JiYWtZB-gbqbU5AfI5uKqVppdEqfmFt2yb7pT5zMl5BOexJmgRWB6oTBNFmzSnkQXLMyw",
        "e": "AQAB",
        "d":
            "CliYwuMUMuQ_AGzplk07feKjROz3azhytO40m_9ttuFggt2HDj5pc7nnBoInt6fUpwyNjbCpu7BwuhcAVl9DJIYQsKWy8vbH1gHXrsHAuF5cN1HGrRMvdumCQh85f3s4S5nlE8MiN-eROPmm8gVMq1Ajtxz0rBumcfAWm2cjgVzSPuBgsenzicG5ufgdyXttTFnhIaAju-FAX2tgP2IwZ9NrB2Oa9WCpTrVD2U8I6DZrpHu4TJfXX7AWkdDhUf0ip1jcwYbVVRzlasTDFLoybovvN_iXJYHzxTNaRGWbnynCFa4nwef95qbnlALZfHYgTzSxK50ne1ztHG9TlUtkWQ",
        "p":
            "5CuAre8JJKCP7Lz3qHPMswv9RGFjGdtToz9KE5iLh5etEuECRnOsEui9I244mPImsf-qoZ85tLx7gRRaZAcp_JEMwkLe-ieLJ-5lqqEODBeuhbSEUmH8sCDyFE4gSTFGT9DK0HwBkKTDrWj5R-L5wGM4K8Ufp_PGhcPjvSg3fMM",
        "q":
            "zw74JjF_s21VHTJXV0gm96CBKhX0InJ2mp-3-lLERHuMydGnm2IgX-bAkCwFSaNwJTUHvvd27KmqSt3cz5VbieSufVuwStChtVVGWnhA_ikAN5QR-xjZlrc2ocWB6dLWbCdjRi4-U7SxDIAu1c-D97u9seDxSFag1uv-QHkzD1k",
        "dp":
            "taZIkLCf19AYJQIgLLTcP6MI4_qgWgJ5qJqHT-h_FNjVChWmqQ4H7RnrEhz65BDMa6M-ZeOMnm376TyZ5c6qR4_212VDfWYj7AtoVxpXQ5tK7tlTCv9Fm7bu4ul73Klk78Aq5yYCXPQ_cHwFEY0LBnY3TulllWGHKBFW6s3stt8",
        "dq":
            "tSknvGL6lAZIve7ZtCgQz__CgwwKOkljtA2iboYT6scee0XQG4dTRBUkzf918OPqruMjD9Z8WrxnnnFXTNgk6xUGBfA-4nZ_xaQClg048Cb3ZalLwiIP3moWhpvD-szZhm8_0JuNNLeXYJSWZcPWdt3wLr3c3anNt71rCwX_wqE",
        "qi":
            "k7vUlnBvM5tJ6ieYP0WSe6I0dq_3GqXZh0n7inpIYtn7Q2pEwRaYAKuiDkrRTA-nNNue4a63i5IZurg3J8TNTQH8aCiLtTSgqH0eDxXgqi_zg51tSLpsXHVZ1R4UmWIpy8NvQ5nhvRu40F5G5hVja_GQzyh0pQdWARzmaXKWEVE",
        "alg": "RS256",
        "kid": "powersync-963d4c3800",
        "use": "sig"
      };

      final privateKey = JsonWebKey.fromJson(privateKeyJwk);
      final now = DateTime.now();
      final normalizedRole = roleName.toUpperCase();
      final expTime = now.add(const Duration(hours: 12));

      final claims = JsonWebTokenClaims.fromJson({
        'sub': 'emp-$empId',
        'iat': now.millisecondsSinceEpoch ~/ 1000,
        'exp': expTime.millisecondsSinceEpoch ~/ 1000,
        'aud': [powerSyncUrl],
        'iss': 'anderson-crm-flutter',
        'emp_id': empId,
        'role': normalizedRole,
        'tenant_id': tenantId,
      });

      final builder = JsonWebSignatureBuilder()
        ..jsonContent = claims.toJson()
        ..addRecipient(privateKey, algorithm: 'RS256');

      final jws = builder.build();
      return jws.toCompactSerialization();
    } catch (e) {
      debugPrint('[BackendConnector] Token generation error: $e');
      return null;
    }
  }

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    debugPrint('[BackendConnector] uploadData()');

    try {
      final transaction = await database.getCrudBatch(limit: 100);

      if (transaction == null || transaction.crud.isEmpty) {
        return;
      }

      debugPrint(
          '[BackendConnector] Processing ${transaction.crud.length} operations');

      for (final operation in transaction.crud) {
        await _processOperation(operation);
      }

      await transaction.complete();
      debugPrint('[BackendConnector] Upload complete');
    } catch (e) {
      debugPrint('[BackendConnector] Upload error: $e');
      rethrow;
    }
  }

  Future<void> _processOperation(CrudEntry operation) async {
    final table = operation.table;

    try {
      switch (table) {
        case 'hc_patient_visit_detail':
          await _handleWorkOrderUpload(operation);
          break;
        case 'price_list':
          await _handlePriceListUpload(operation);
          break;
        default:
          debugPrint('[BackendConnector] Unknown table: $table');
          return;
      }
    } catch (e) {
      debugPrint(
          '[BackendConnector] Operation failed: ${operation.op} on $table - $e');
      rethrow;
    }
  }

  // Work Order Handlers
  Future<void> _handleWorkOrderUpload(CrudEntry operation) async {
    final id = operation.id;
    final data = operation.opData;

    switch (operation.op) {
      case UpdateType.put:
        await _upsertWorkOrder(id, data!);
        break;
      case UpdateType.patch:
        await _updateWorkOrder(id, data!);
        break;
      case UpdateType.delete:
        await _deleteWorkOrder(id);
        break;
    }
  }

  // Price List Handlers
  Future<void> _handlePriceListUpload(CrudEntry operation) async {
    final id = operation.id;
    final data = operation.opData;

    switch (operation.op) {
      case UpdateType.put:
        await _upsertPriceList(id, data!);
        break;
      case UpdateType.patch:
        await _updatePriceList(id, data!);
        break;
      case UpdateType.delete:
        await _deletePriceList(id);
        break;
    }
  }

  // Work Order CRUD
  Future<void> _upsertWorkOrder(String id, Map<String, dynamic> data) async {
    final url = '$postgrestBaseUrl/hc_patient_visit_detail';
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );

    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception('WorkOrder insert failed: ${response.statusCode}');
    }
  }

  Future<void> _updateWorkOrder(String id, Map<String, dynamic> data) async {
    final url = '$postgrestBaseUrl/hc_patient_visit_detail?id=eq.$id';
    final response = await http.patch(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('WorkOrder update failed: ${response.statusCode}');
    }
  }

  Future<void> _deleteWorkOrder(String id) async {
    final url = '$postgrestBaseUrl/hc_patient_visit_detail?doc_id=eq.$id';
    final response = await http.delete(Uri.parse(url));

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('WorkOrder delete failed: ${response.statusCode}');
    }
  }

  // Price List CRUD
  Future<void> _upsertPriceList(String id, Map<String, dynamic> data) async {
    // Use Settings for production URL
    final baseUrl = Settings.currentPostgresUrl;
    final url = '$baseUrl/price_list';

    // Ensure data has the ID
    final dataWithId = {...data, 'id': id};

    debugPrint('[BackendConnector] Upserting price_list: $id');

    // Get auth token for production
    final token = await storage.getFromSessionAsync('pg_admin');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      // PostgREST upsert: ON CONFLICT (id) DO UPDATE
      'Prefer': 'resolution=merge-duplicates,return=minimal',
    };

    // Add auth if available (required in production)
    if (token.isNotEmpty && !Settings.development) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(dataWithId),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[BackendConnector] Price list upserted: $id');
        return;
      }

      // Log detailed error for debugging
      debugPrint('[BackendConnector] Upsert failed: ${response.statusCode}');
      debugPrint('[BackendConnector] Response: ${response.body}');
      throw Exception(
          'PriceList upsert failed: ${response.statusCode} - ${response.body}');
    } catch (e) {
      debugPrint('[BackendConnector] Upsert exception: $e');
      rethrow;
    }
  }

  Future<void> _updatePriceList(String id, Map<String, dynamic> data) async {
    final baseUrl = Settings.currentPostgresUrl;
    final url = '$baseUrl/price_list?id=eq.$id';

    final token = await storage.getFromSessionAsync('pg_admin');
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (token.isNotEmpty && !Settings.development) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await http.patch(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode(data),
    );

    if (response.statusCode != 204 && response.statusCode != 200) {
      debugPrint(
          '[BackendConnector] Update failed: ${response.statusCode} - ${response.body}');
      throw Exception('PriceList update failed: ${response.statusCode}');
    }
    debugPrint('[BackendConnector] Price list updated: $id');
  }

  Future<void> _deletePriceList(String id) async {
    // Soft delete: set visible = 0 (integer for PostgreSQL)
    final baseUrl = Settings.currentPostgresUrl;
    final url = '$baseUrl/price_list?id=eq.$id';

    final token = await storage.getFromSessionAsync('pg_admin');
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (token.isNotEmpty && !Settings.development) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await http.patch(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode({'visible': 0}), // Use 0 for integer column
    );

    if (response.statusCode != 204 && response.statusCode != 200) {
      debugPrint(
          '[BackendConnector] Delete failed: ${response.statusCode} - ${response.body}');
      throw Exception('PriceList soft delete failed: ${response.statusCode}');
    }
    debugPrint('[BackendConnector] Price list soft deleted: $id');
  }

  Future<bool> checkConnection() async {
    try {
      final response = await http
          .get(Uri.parse('$apiUrl/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[BackendConnector] Connection check failed: $e');
      return false;
    }
  }
}
