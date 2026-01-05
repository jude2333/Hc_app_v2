import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:anderson_crm_flutter/providers/couch_db_provider.dart';

class CouchDBService {
  CouchDBService(this.ref);

  final Ref ref;

  Future<Dio> _db(String dbName) =>
      ref.read(couchDbClientProvider).getDB(dbName);
  Future<Dio> getDB(String dbName) => _db(dbName);

  String _handleError(Object e) {
    if (e is DioException) {
      return 'CouchDB: ${e.response?.statusCode} ${e.response?.statusMessage}';
    }
    return 'CouchDB: $e';
  }

  Future<String> upsert(String dbName, Map<String, dynamic> doc) async {
    try {
      final dio = await _db(dbName);
      final id = doc['_id'] as String;
      final resp = await dio.put('/$id', data: doc);
      return resp.statusCode == 201 || resp.statusCode == 202
          ? 'OK'
          : 'ERROR: ${resp.statusCode}';
    } catch (e) {
      debugPrint(_handleError(e));
      return 'ERROR: ${_handleError(e)}';
    }
  }

  Future<Map<String, dynamic>?> get(
    String dbName,
    String id,
  ) async {
    try {
      final dio = await _db(dbName);
      final resp = await dio.get('/$id');
      return resp.data as Map<String, dynamic>;
    } catch (e) {
      debugPrint(_handleError(e));
      return null;
    }
  }

  Future<bool> delete(
    String dbName,
    String id,
    String rev,
  ) async {
    try {
      final dio = await _db(dbName);
      final resp = await dio.delete('/$id', queryParameters: {'rev': rev});
      return resp.statusCode == 200;
    } catch (e) {
      debugPrint(_handleError(e));
      return false;
    }
  }

  Future<String> bulkDocs(
    String dbName,
    List<Map<String, dynamic>> docs,
  ) async {
    try {
      final dio = await _db(dbName);
      final resp = await dio.post('/_bulk_docs',
          data: {'docs': docs},
          options: Options(headers: {'Content-Type': 'application/json'}));
      return resp.statusCode == 201 ? 'OK' : 'ERROR: ${resp.statusCode}';
    } catch (e) {
      debugPrint(_handleError(e));
      return 'ERROR: ${_handleError(e)}';
    }
  }

  Future<List<Map<String, dynamic>>> queryView(
    String dbName, {
    required String designDoc,
    required String viewName,
    Map<String, dynamic>? params,
  }) async {
    try {
      final dio = await _db(dbName);
      final resp = await dio.get('/_design/$designDoc/_view/$viewName',
          queryParameters: params);
      final rows = (resp.data['rows'] as List)
          .cast<Map<String, dynamic>>()
          .map((r) => r['doc'] ?? r['value'])
          .cast<Map<String, dynamic>>()
          .toList();
      return rows;
    } catch (e) {
      debugPrint(_handleError(e));
      return [];
    }
  }
}

final couchDBServiceProvider = Provider<CouchDBService>((ref) {
  return CouchDBService(ref);
});
