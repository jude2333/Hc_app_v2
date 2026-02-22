import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:powersync/powersync.dart';
import 'package:jose/jose.dart';
import 'package:anderson_crm_flutter/services/storage_service.dart';
import '../../config/settings.dart';

/// Structured exception for PostgREST HTTP errors.
/// Enables reliable status code checking in _isPermanentError.
class PostgRESTException implements Exception {
  final String message;
  final int statusCode;
  final String responseBody;

  PostgRESTException(this.message, this.statusCode, this.responseBody);

  @override
  String toString() =>
      'PostgRESTException($statusCode): $message - $responseBody';
}

class BackendConnector extends PowerSyncBackendConnector {
  final StorageService storage;

  // Platform-adaptive API URLs
  // static String get apiUrl {
  //   if (kIsWeb) {
  //     return 'http://localhost:5000';
  //   } else {
  //     return 'http://10.0.2.2:5000';
  //   }
  // }

  final Future<void> Function()? onRefreshToken;

  String get postgrestBaseUrl {
    return Settings.currentPostgresUrl;
  }

  final String powerSyncUrl = Settings.powerSyncUrl;

  BackendConnector({required this.storage, this.onRefreshToken});

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    debugPrint('[BackendConnector] fetchCredentials()');

    try {
      final token = await _getAuthToken();

      if (token == null) {
        debugPrint('[BackendConnector] Failed to get auth token');
        return null;
      }

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

  /// Postgres response codes that indicate fatal (non-retryable) errors.
  /// Matches the official PowerSync Supabase demo pattern.
  static final List<RegExp> _fatalPostgresCodes = [
    // Class 22 — Data Exception (e.g. data type mismatch, invalid JSON)
    RegExp(r'^22...$'),
    // Class 23 — Integrity Constraint Violation (NOT NULL, FK, UNIQUE)
    RegExp(r'^23...$'),
    // INSUFFICIENT PRIVILEGE — typically a row-level security violation
    RegExp(r'^42501$'),
  ];

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    debugPrint('[BackendConnector] uploadData()');

    // Use getNextCrudTransaction() per official PowerSync pattern.
    // Processes one transaction at a time so write checkpoints advance
    // correctly, preventing "Could not apply checkpoint due to local data".
    final transaction = await database.getNextCrudTransaction();

    if (transaction == null) return;

    debugPrint(
        '[BackendConnector] Processing transaction with ${transaction.crud.length} operations');

    CrudEntry? lastOp;
    try {
      for (final operation in transaction.crud) {
        lastOp = operation;
        await _processOperation(operation);
      }

      // All operations successful — advance the write checkpoint.
      await transaction.complete();
      debugPrint('[BackendConnector] Transaction completed successfully ✅');
    } catch (e) {
      debugPrint('[BackendConnector] Upload error on $lastOp: $e');

      if (_isPermanentError(e)) {
        // Fatal Postgres errors (data type mismatch, constraint violations)
        // should NOT block the queue. Discard and move on.
        debugPrint(
            '[BackendConnector] ⚠️ Fatal error, discarding transaction: $e');
        await transaction.complete();
      } else {
        // Transient errors (network, 5xx, 401) — let PowerSync retry
        rethrow;
      }
    }
  }

  /// Check if an error is permanent (should not be retried).
  /// Uses Postgres error codes from the PostgREST JSON response body,
  /// matching the official PowerSync Supabase demo pattern.
  bool _isPermanentError(dynamic error) {
    if (error is PostgRESTException) {
      // 401 is Transient (Token Expired) -> Retry (with refresh)
      if (error.statusCode == 401) return false;

      // Try to extract Postgres error code from PostgREST JSON response
      try {
        final body = jsonDecode(error.responseBody);
        final pgCode = body['code']?.toString();
        if (pgCode != null) {
          final isFatal = _fatalPostgresCodes.any((re) => re.hasMatch(pgCode));
          debugPrint(
              '[BackendConnector] Postgres code: $pgCode, fatal: $isFatal');
          return isFatal;
        }
      } catch (_) {
        // Response body not valid JSON — fall through to status code check
      }

      // Fallback: 4xx (except 401, 409, 429) are likely permanent
      if (error.statusCode == 409 || error.statusCode == 429) return false;
      return error.statusCode >= 400 && error.statusCode < 500;
    }
    // Fallback: check for known permanent error patterns
    final errorStr = error.toString();
    if (errorStr.contains('FormatException') ||
        errorStr.contains('type \'') ||
        errorStr.contains('is not a subtype')) {
      return true;
    }
    return false;
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
        case 'temp_uploads':
          await _handleTempUploadSync(operation);
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
        // Ensure sync_window is always true for new/edited work orders
        data!['sync_window'] = 1;
        await _upsertWorkOrder(id, data);
        break;
      case UpdateType.patch:
        // Ensure sync_window is always true for updated work orders
        data!['sync_window'] = 1;
        await _updateWorkOrder(id, data);
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
        // Create a copy to avoid mutating opData in place
        final payload = Map<String, dynamic>.from(data!);
        await _upsertPriceList(id, payload);
        break;
      case UpdateType.patch:
        // Create a copy to avoid mutating opData in place
        final payload = Map<String, dynamic>.from(data!);
        payload.remove('id'); // PowerSync id != Postgres PK
        await _updatePriceList(id, payload);
        break;
      case UpdateType.delete:
        await _deletePriceList(id);
        break;
    }
  }

  // Work Order CRUD
  Future<void> _upsertWorkOrder(String id, Map<String, dynamic> data) async {
    final baseUrl = Settings.currentPostgresUrl;
    final url = '$baseUrl/hc_patient_visit_detail';

    // Decode doc from String→Map to prevent double-encoding into jsonb
    if (data['doc'] is String) {
      try {
        data['doc'] = jsonDecode(data['doc'] as String);
      } catch (e) {
        debugPrint('[BackendConnector] _upsertWorkOrder jsonDecode error: $e');
      }
    }

    final payload = Map<String, dynamic>.from(data);
    // payload.remove('id');

    int retryCount = 0;
    while (retryCount < 2) {
      final token = await storage.getFromSessionAsync('pg_admin');
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Prefer': 'resolution=merge-duplicates,return=minimal',
        'Authorization': 'Bearer $token',
      };

      try {
        final response = await http
            .post(
              Uri.parse(url),
              headers: headers,
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200 || response.statusCode == 201) {
          return;
        }

        if (response.statusCode == 401 &&
            retryCount == 0 &&
            onRefreshToken != null) {
          debugPrint('[BackendConnector] 401 detected, refreshing token...');
          await onRefreshToken!();
          retryCount++;
          continue;
        }

        debugPrint('[BackendConnector] Upsert failed: ${response.statusCode}');
        debugPrint('[BackendConnector] Response: ${response.body}');
        throw PostgRESTException(
            'WorkOrder upsert failed', response.statusCode, response.body);
      } catch (e) {
        if (e is PostgRESTException &&
            e.statusCode == 401 &&
            retryCount == 0 &&
            onRefreshToken != null) {
          debugPrint(
              '[BackendConnector] 401 Exception detected, refreshing token...');
          await onRefreshToken!();
          retryCount++;
          continue;
        }
        debugPrint('[BackendConnector] Upsert exception: $e');
        rethrow;
      }
    }
  }

  Future<void> _updateWorkOrder(String id, Map<String, dynamic> data) async {
    final baseUrl = Settings.currentPostgresUrl;

    // Detect ID format:
    // - All digits → old cached integer PK (before sync rule change)
    // - Contains non-digits → doc_id string (after sync rule change: doc_id as id)
    final isIntegerId = RegExp(r'^\d+$').hasMatch(id);
    final String url;
    if (isIntegerId) {
      url = '$baseUrl/hc_patient_visit_detail?id=eq.$id';
      debugPrint('[BackendConnector] PATCH using integer PK: $id');
    } else {
      url = '$baseUrl/hc_patient_visit_detail?doc_id=eq.$id';
    }

    // IMPORTANT: Create a COPY of the data before modifying.
    // Do NOT mutate operation.opData in place — PowerSync uses
    // the original opData for write checkpoint reconciliation.
    final payload = Map<String, dynamic>.from(data);

    // Strip fields that don't belong in the PostgREST PATCH payload.
    // - id: PowerSync uses doc_id as id, but Postgres has an integer PK
    payload.remove('id');

    // Decode doc from String→Map to prevent double-encoding into jsonb
    if (payload['doc'] is String) {
      try {
        payload['doc'] = jsonDecode(payload['doc'] as String);
      } catch (_) {}
    }

    int retryCount = 0;
    while (retryCount < 2) {
      final token = await storage.getFromSessionAsync('pg_admin');
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
        'Authorization': 'Bearer $token',
      };

      try {
        debugPrint('[BackendConnector] Sending PATCH to $url');
        final body = jsonEncode(payload);

        final response = await http
            .patch(
              Uri.parse(url),
              headers: headers,
              body: body,
            )
            .timeout(const Duration(seconds: 15));

        debugPrint(
            '[BackendConnector] PATCH response status: ${response.statusCode}');

        if (response.statusCode == 200) {
          // Verify at least one row was updated
          final rows = jsonDecode(response.body);
          if (rows is List && rows.isEmpty) {
            // 0 rows matched — row may have been deleted. Log and move on.
            // Don't upsert: PATCH data is partial (missing required fields).
            debugPrint(
                '[BackendConnector] ⚠️ PATCH matched 0 rows for id=$id — row may not exist on server');
            return;
          }

          debugPrint('[BackendConnector] ✅ Work order updated: id=$id');
          return;
        }

        if (response.statusCode == 401 &&
            retryCount == 0 &&
            onRefreshToken != null) {
          debugPrint(
              '[BackendConnector] 401 detected in PATCH, refreshing token...');
          await onRefreshToken!();
          retryCount++;
          continue;
        }

        debugPrint(
            '[BackendConnector] Update failed: ${response.statusCode} - ${response.body}');
        throw PostgRESTException(
            'WorkOrder update failed', response.statusCode, response.body);
      } catch (e) {
        if (e is PostgRESTException &&
            e.statusCode == 401 &&
            retryCount == 0 &&
            onRefreshToken != null) {
          debugPrint(
              '[BackendConnector] 401 Exception detected in PATCH, refreshing token...');
          await onRefreshToken!();
          retryCount++;
          continue;
        }
        debugPrint('[BackendConnector] Update exception: $e');
        rethrow;
      }
    }
  }

  Future<void> _deleteWorkOrder(String id) async {
    final baseUrl = Settings.currentPostgresUrl;

    // Detect ID format: integer PK (old) vs doc_id string (new)
    final isIntegerId = RegExp(r'^\d+$').hasMatch(id);
    final String url;
    if (isIntegerId) {
      url = '$baseUrl/hc_patient_visit_detail?id=eq.$id';
    } else {
      url = '$baseUrl/hc_patient_visit_detail?doc_id=eq.$id';
    }

    final token = await storage.getFromSessionAsync('pg_admin');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final response = await http
        .delete(
          Uri.parse(url),
          headers: headers,
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 204 && response.statusCode != 200) {
      debugPrint(
          '[BackendConnector] Delete failed: ${response.statusCode} - ${response.body}');
      throw PostgRESTException(
          'WorkOrder delete failed', response.statusCode, response.body);
    }
    debugPrint('[BackendConnector] Work order deleted: $id');
  }

  Future<void> _upsertPriceList(String id, Map<String, dynamic> data) async {
    final baseUrl = Settings.currentPostgresUrl;
    final url = '$baseUrl/price_list';

    // Decode history from String→List to prevent double-encoding into jsonb
    if (data['history'] is String) {
      try {
        data['history'] = jsonDecode(data['history'] as String);
      } catch (_) {}
    }

    final dataWithId = {...data, 'id': id};

    debugPrint('[BackendConnector] Upserting price_list: $id');

    final token = await storage.getFromSessionAsync('pg_admin');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Prefer': 'resolution=merge-duplicates,return=minimal',
      'Authorization': 'Bearer $token',
    };

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: headers,
            body: jsonEncode(dataWithId),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[BackendConnector] Price list upserted: $id');
        return;
      }

      debugPrint('[BackendConnector] Upsert failed: ${response.statusCode}');
      throw PostgRESTException(
          'PriceList upsert failed', response.statusCode, response.body);
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
      'Authorization': 'Bearer $token',
    };

    // Decode history from String→List to prevent double-encoding into jsonb
    if (data['history'] is String) {
      try {
        data['history'] = jsonDecode(data['history'] as String);
      } catch (_) {}
    }

    final response = await http
        .patch(
          Uri.parse(url),
          headers: headers,
          body: jsonEncode(data),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 204 && response.statusCode != 200) {
      debugPrint(
          '[BackendConnector] Update failed: ${response.statusCode} - ${response.body}');
      throw PostgRESTException(
          'PriceList update failed', response.statusCode, response.body);
    }
    debugPrint('[BackendConnector] Price list updated: $id');
  }

  Future<void> _deletePriceList(String id) async {
    final baseUrl = Settings.currentPostgresUrl;
    final url = '$baseUrl/price_list?id=eq.$id';

    final token = await storage.getFromSessionAsync('pg_admin');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final response = await http
        .patch(
          Uri.parse(url),
          headers: headers,
          body: jsonEncode({'visible': 0}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 204 && response.statusCode != 200) {
      debugPrint(
          '[BackendConnector] Delete failed: ${response.statusCode} - ${response.body}');
      throw PostgRESTException(
          'PriceList soft delete failed', response.statusCode, response.body);
    }
    debugPrint('[BackendConnector] Price list soft deleted: $id');
  }

  // Future<bool> checkConnection() async {
  //   try {
  //     final response = await http
  //         .get(Uri.parse('$apiUrl/health'))
  //         .timeout(const Duration(seconds: 5));
  //     return response.statusCode == 200;
  //   } catch (e) {
  //     debugPrint('[BackendConnector] Connection check failed: $e');
  //     return false;
  //   }
  // }

  // Temp Uploads Handlers (for prescription photos)
  Future<void> _handleTempUploadSync(CrudEntry operation) async {
    final id = operation.id;
    final data = operation.opData;

    switch (operation.op) {
      case UpdateType.put:
        await _upsertTempUpload(id, data!);
        break;
      case UpdateType.patch:
        await _updateTempUpload(id, data!);
        break;
      case UpdateType.delete:
        await _deleteTempUpload(id);
        break;
    }
  }

  Future<void> _upsertTempUpload(String id, Map<String, dynamic> data) async {
    final baseUrl = Settings.currentPostgresUrl;
    final url = '$baseUrl/temp_uploads';

    final dataWithId = {...data, 'id': id};

    debugPrint('[BackendConnector] Syncing temp upload: $id');

    final token = await storage.getFromSessionAsync('pg_admin');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Prefer': 'resolution=merge-duplicates,return=minimal',
      'Authorization': 'Bearer $token',
    };

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: headers,
            body: jsonEncode(dataWithId),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('[BackendConnector] Temp upload synced: $id');
      } else {
        debugPrint(
            '[BackendConnector] Temp upload sync failed: ${response.statusCode} - ${response.body}');
        throw PostgRESTException(
            'TempUpload upsert failed', response.statusCode, response.body);
      }
    } catch (e) {
      debugPrint('[BackendConnector] Temp upload sync error: $e');
      rethrow;
    }
  }

  Future<void> _updateTempUpload(String id, Map<String, dynamic> data) async {
    final baseUrl = Settings.currentPostgresUrl;
    final url = '$baseUrl/temp_uploads?id=eq.$id';

    debugPrint('[BackendConnector] Updating temp upload: $id');

    final token = await storage.getFromSessionAsync('pg_admin');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final response = await http
        .patch(
          Uri.parse(url),
          headers: headers,
          body: jsonEncode(data),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 204 && response.statusCode != 200) {
      debugPrint(
          '[BackendConnector] Temp upload update failed: ${response.statusCode}');
      throw PostgRESTException(
          'TempUpload update failed', response.statusCode, response.body);
    }
    debugPrint('[BackendConnector] Temp upload updated: $id');
  }

  Future<void> _deleteTempUpload(String id) async {
    final baseUrl = Settings.currentPostgresUrl;
    final url = '$baseUrl/temp_uploads?id=eq.$id';

    debugPrint('[BackendConnector] Deleting temp upload: $id');

    final token = await storage.getFromSessionAsync('pg_admin');
    final headers = <String, String>{
      'Authorization': 'Bearer $token',
    };

    final response = await http
        .delete(
          Uri.parse(url),
          headers: headers,
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 204 && response.statusCode != 200) {
      debugPrint(
          '[BackendConnector] Temp upload delete failed: ${response.statusCode}');
      throw PostgRESTException(
          'TempUpload delete failed', response.statusCode, response.body);
    }
    debugPrint('[BackendConnector] Temp upload deleted: $id');
  }
}
