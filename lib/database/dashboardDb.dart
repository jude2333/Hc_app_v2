import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/storage_repository.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import '../config/settings.dart';

class DashboardDB {
  final StorageRepository _storage;
  Dio? _client;

  DashboardDB(this._storage);

  Future<Dio> _getClient() async {
    if (_client != null) return _client!;

    final String? token = await _storage.getSessionItem("pg_admin");

    _client = Dio(BaseOptions(
      baseUrl: Settings.currentPostgresUrl,
      // connectTimeout maps to sendTimeout on web (unsupported for GET without body)
      connectTimeout: kIsWeb ? null : const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        "Content-Type": "application/json",
        if (token != null && token.isNotEmpty) "Authorization": "Bearer $token",
      },
    ));
    return _client!;
  }

  Future<Map<String, dynamic>?> getOne(String docId) async {
    try {
      final String? tenantId =
          await _storage.getSessionItem("logged_in_tenant_id");
      if (tenantId == null) {
        debugPrint(" Dashboard tenant ID not found in session");
        return null;
      }

      String reportType;
      String reportKey;

      if (docId == 'yearly') {
        reportType = 'yearly_summary';
        reportKey = 'all';
      } else if (docId.startsWith('yearly_')) {
        reportType = 'yearly_month';
        reportKey = docId.substring(7);
      } else {
        final idx = docId.indexOf('_');
        if (idx == -1) return null;
        reportType = docId.substring(0, idx);
        reportKey = docId.substring(idx + 1);
      }

      debugPrint(
          " Fetching Postgres dashboard: type=$reportType key=$reportKey tenant=$tenantId");

      final client = await _getClient();

      final response = await client.get("/hc_dashboard", queryParameters: {
        "select": "data",
        "tenant_id": "eq.$tenantId",
        "report_type": "eq.$reportType",
        "report_key": "eq.$reportKey"
      });

      if (response.statusCode == 200 &&
          response.data != null &&
          (response.data as List).isNotEmpty) {
        debugPrint(" Successfully fetched Postgres dashboard document");
        return {'data': response.data[0]['data']};
      }
      return null;
    } catch (e) {
      debugPrint(" Error fetching dashboard document '$docId': $e");
      // Reset client on auth errors so next call re-creates with fresh token
      if (e is DioException && e.response?.statusCode == 401) {
        _client = null;
      }
      return null;
    }
  }

  // The following methods are required by the DashboardService interface
  // but are not actually used by the current dashboard providers (which only use getOne).
  // They are stubbed out to avoid breaking the interface if called.

  Future<List<Map<String, dynamic>>> getMultiple(List<String> docIds) async {
    debugPrint("DashboardDB.getMultiple not supported in Postgres migration");
    return [];
  }

  Future<List<Map<String, dynamic>>> getAll() async {
    debugPrint("DashboardDB.getAll not supported in Postgres migration");
    return [];
  }

  Future<List<Map<String, dynamic>>> query(
      {bool Function(Map<String, dynamic>)? filter}) async {
    debugPrint("DashboardDB.query not supported in Postgres migration");
    return [];
  }

  Future<String> put(String docId, Map<String, dynamic> doc) async {
    debugPrint("DashboardDB.put not supported in Postgres migration");
    return "";
  }

  Future<String> delete(String docId) async {
    debugPrint("DashboardDB.delete not supported in Postgres migration");
    return "";
  }

  Future<bool> exists(String docId) async {
    final doc = await getOne(docId);
    return doc != null;
  }
}

final dashboardDbProvider = Provider<DashboardDB>((ref) {
  final storage = ref.watch(storageRepositoryProvider);
  return DashboardDB(storage);
});
