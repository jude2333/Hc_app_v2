import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/storage_repository.dart';
import 'db_handler.dart';
import 'couch_db.dart';
import 'package:anderson_crm_flutter/providers/db_handler_provider.dart';
import 'package:anderson_crm_flutter/providers/couch_db_provider.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';

class DashboardDB {
  final DBHandler _dbHandler;
  final CouchDBClient _couchDB;
  final StorageRepository _storage;

  DashboardDB(this._dbHandler, this._couchDB, this._storage);

  Future<Map<String, dynamic>?> getOne(String docId) async {
    try {
      String? tenant = await _storage.getSessionItem("dashboard_tenant_name");
      if (tenant == null || tenant.isEmpty) {
        debugPrint("❌ Dashboard tenant name not found in session");
        return null;
      }

      String fullDocId = "${tenant}_$docId";
      debugPrint("📄 Fetching dashboard document: $fullDocId");

      String? dbName = _dbHandler.resolveName("dashboard");
      if (dbName == null) {
        debugPrint("❌ Could not resolve dashboard database name");
        return null;
      }

      Dio remoteDb = await _couchDB.getDB(dbName);

      Response response = await remoteDb.get("/$fullDocId");

      if (response.statusCode == 200) {
        Map<String, dynamic> doc = Map<String, dynamic>.from(response.data);
        debugPrint("✅ Successfully fetched dashboard document: $fullDocId");
        return doc;
      } else {
        debugPrint("❌ Failed to fetch document: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      debugPrint("❌ Error fetching dashboard document '$docId': $e");
      if (e is DioException) {
        if (e.response?.statusCode == 404) {
          debugPrint("📭 Document not found: $docId");
        } else {
          debugPrint("Response: ${e.response?.data}");
        }
      }
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getMultiple(List<String> docIds) async {
    try {
      String? tenant = await _storage.getSessionItem("dashboard_tenant_name");
      if (tenant == null || tenant.isEmpty) {
        debugPrint("❌ Dashboard tenant name not found in session");
        return [];
      }

      List<String> fullDocIds = docIds.map((id) => "${tenant}_$id").toList();
      debugPrint("📄 Fetching ${fullDocIds.length} dashboard documents");

      String? dbName = _dbHandler.resolveName("dashboard");
      if (dbName == null) {
        debugPrint("❌ Could not resolve dashboard database name");
        return [];
      }

      Dio remoteDb = await _couchDB.getDB(dbName);

      Response response = await remoteDb.post(
        "/_all_docs",
        data: {
          "keys": fullDocIds,
          "include_docs": true,
        },
      );

      if (response.statusCode == 200) {
        List<Map<String, dynamic>> docs = [];
        List<dynamic> rows = response.data['rows'] ?? [];

        for (var row in rows) {
          if (row['doc'] != null && row['error'] == null) {
            docs.add(Map<String, dynamic>.from(row['doc']));
          }
        }

        debugPrint("✅ Successfully fetched ${docs.length} dashboard documents");
        return docs;
      } else {
        debugPrint("❌ Failed to fetch documents: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      debugPrint("❌ Error fetching multiple dashboard documents: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAll() async {
    try {
      String? tenant = await _storage.getSessionItem("dashboard_tenant_name");
      if (tenant == null || tenant.isEmpty) {
        debugPrint("❌ Dashboard tenant name not found in session");
        return [];
      }

      debugPrint("📄 Fetching all dashboard documents for tenant: $tenant");

      String? dbName = _dbHandler.resolveName("dashboard");
      if (dbName == null) {
        debugPrint("❌ Could not resolve dashboard database name");
        return [];
      }

      Dio remoteDb = await _couchDB.getDB(dbName);

      Response response = await remoteDb.get(
        "/_all_docs",
        queryParameters: {
          "include_docs": true,
          "startkey": jsonEncode("${tenant}_"),
          "endkey": jsonEncode("${tenant}_\ufff0"),
        },
      );

      if (response.statusCode == 200) {
        List<Map<String, dynamic>> docs = [];
        List<dynamic> rows = response.data['rows'] ?? [];

        for (var row in rows) {
          if (row['doc'] != null) {
            docs.add(Map<String, dynamic>.from(row['doc']));
          }
        }

        debugPrint("✅ Successfully fetched ${docs.length} dashboard documents");
        return docs;
      } else {
        debugPrint("❌ Failed to fetch all documents: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      debugPrint("❌ Error fetching all dashboard documents: $e");
      return [];
    }
  }

  Future<String> put(String docId, Map<String, dynamic> doc) async {
    try {
      String? tenant = await _storage.getSessionItem("dashboard_tenant_name");
      if (tenant == null || tenant.isEmpty) {
        debugPrint("❌ Dashboard tenant name not found in session");
        return "ERROR: Tenant name not found";
      }

      String fullDocId = "${tenant}_$docId";
      doc['_id'] = fullDocId;

      debugPrint("📝 Updating dashboard document: $fullDocId");

      String? dbName = _dbHandler.resolveName("dashboard");
      if (dbName == null) {
        debugPrint("❌ Could not resolve dashboard database name");
        return "ERROR: Database name not resolved";
      }

      Dio remoteDb = await _couchDB.getDB(dbName);

      try {
        Response getResponse = await remoteDb.get("/$fullDocId");
        if (getResponse.statusCode == 200) {
          doc['_rev'] = getResponse.data['_rev'];
          debugPrint("📌 Got current rev: ${doc['_rev']}");
        }
      } catch (e) {
        debugPrint("📄 Document doesn't exist yet, creating new one");
      }

      Response response = await remoteDb.put(
        "/$fullDocId",
        data: doc,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint("✅ Successfully updated dashboard document: $fullDocId");
        return "OK";
      } else {
        debugPrint("❌ Failed to update document: ${response.statusCode}");
        return "ERROR: ${response.statusMessage ?? 'Update failed'}";
      }
    } catch (e) {
      debugPrint("❌ Error updating dashboard document '$docId': $e");
      if (e is DioException) {
        debugPrint("Response: ${e.response?.data}");
        if (e.response?.statusCode == 409) {
          return "ERROR: Conflict - Document was modified by another user";
        }
      }
      return "ERROR: $e";
    }
  }

  Future<String> delete(String docId) async {
    try {
      String? tenant = await _storage.getSessionItem("dashboard_tenant_name");
      if (tenant == null || tenant.isEmpty) {
        debugPrint("❌ Dashboard tenant name not found in session");
        return "ERROR: Tenant name not found";
      }

      String fullDocId = "${tenant}_$docId";
      debugPrint("🗑️ Deleting dashboard document: $fullDocId");

      String? dbName = _dbHandler.resolveName("dashboard");
      if (dbName == null) {
        debugPrint("❌ Could not resolve dashboard database name");
        return "ERROR: Database name not resolved";
      }

      Dio remoteDb = await _couchDB.getDB(dbName);

      Response getResponse = await remoteDb.get("/$fullDocId");
      if (getResponse.statusCode != 200) {
        debugPrint("❌ Document not found: $fullDocId");
        return "ERROR: Document not found";
      }

      String rev = getResponse.data['_rev'];

      Response response = await remoteDb.delete(
        "/$fullDocId",
        queryParameters: {"rev": rev},
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        debugPrint("✅ Successfully deleted dashboard document: $fullDocId");
        return "OK";
      } else {
        debugPrint("❌ Failed to delete document: ${response.statusCode}");
        return "ERROR: ${response.statusMessage ?? 'Delete failed'}";
      }
    } catch (e) {
      debugPrint("❌ Error deleting dashboard document '$docId': $e");
      if (e is DioException) {
        debugPrint("Response: ${e.response?.data}");
      }
      return "ERROR: $e";
    }
  }

  Future<List<Map<String, dynamic>>> query({
    bool Function(Map<String, dynamic>)? filter,
  }) async {
    try {
      List<Map<String, dynamic>> allDocs = await getAll();

      if (filter != null) {
        return allDocs.where(filter).toList();
      }

      return allDocs;
    } catch (e) {
      debugPrint("❌ Error querying dashboard documents: $e");
      return [];
    }
  }

  Future<bool> exists(String docId) async {
    try {
      String? tenant = await _storage.getSessionItem("dashboard_tenant_name");
      if (tenant == null || tenant.isEmpty) {
        return false;
      }

      String fullDocId = "${tenant}_$docId";

      String? dbName = _dbHandler.resolveName("dashboard");
      if (dbName == null) {
        return false;
      }

      Dio remoteDb = await _couchDB.getDB(dbName);

      Response response = await remoteDb.head("/$fullDocId");

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

final dashboardDbProvider = Provider<DashboardDB>((ref) {
  final dbHandler = ref.watch(dbHandlerProvider);
  final couchDb = ref.watch(couchDbClientProvider);
  final storage = ref.watch(storageRepositoryProvider);
  return DashboardDB(dbHandler, couchDb, storage);
});
