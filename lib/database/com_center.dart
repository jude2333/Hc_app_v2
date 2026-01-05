import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:anderson_crm_flutter/config/settings.dart';
import 'package:anderson_crm_flutter/repositories/storage_repository.dart';

class ComCenter {
  final StorageRepository _storage;

  Dio? _client;
  String _token = "";

  ComCenter(this._storage);

  Future<void> _setup() async {
    if (_token.isEmpty) {
      _token = await _storage.getSessionItem("pg_admin") ?? "";
    }

    final options = BaseOptions(
      baseUrl: '${Settings.remoteCouchUrl}/com_center',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    );

    final headers = <String, String>{
      "Content-Type": "application/json",
    };

    if (_token.isNotEmpty) {
      headers["Authorization"] = "Bearer $_token";
    }

    _client = Dio(options)
      ..options.headers = headers
      ..options.validateStatus = (status) => status != null && status < 500;

    debugPrint('📡 ComCenter setup complete');
  }

  Future<String> sendMsg(Map<String, dynamic> message) async {
    if (_client == null) {
      await _setup();
    }

    try {
      if (!message.containsKey('_id')) {
        return 'Error: Message must have an _id field';
      }

      String docId = message['_id'];
      debugPrint('📤 Uploading message to CouchDB: $docId');

      message['_id'] = docId;
      // message.remove('_local_modified');

      Response response = await _client!.put(
        '/$docId',
        data: message,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ Message uploaded successfully: $docId');
        return 'OK';
      } else if (response.statusCode == 409) {
        debugPrint('⚠️ Document conflict (409), resolving...');
        return await _resolveConflictAndRetry(docId, message);
      } else {
        debugPrint('❌ Failed to upload message: ${response.statusCode}');
        return 'Error: ${response.statusMessage}';
      }
    } catch (error, stackTrace) {
      if (error is DioException && error.response?.statusCode == 409) {
        return await _resolveConflictAndRetry(message['_id'], message);
      }

      debugPrint('❌ Error uploading message: $error');
      debugPrint('Stack trace: $stackTrace');
      return 'Error: $error';
    }
  }

  Future<String> _resolveConflictAndRetry(
      String docId, Map<String, dynamic> localDoc) async {
    try {
      debugPrint('🔄 Fetching remote document: $docId');

      Response getResponse = await _client!.get('/$docId');

      if (getResponse.statusCode == 200) {
        Map<String, dynamic> remoteDoc =
            Map<String, dynamic>.from(getResponse.data);
        String remoteRev = remoteDoc['_rev'];

        debugPrint('📝 Remote _rev: $remoteRev');
        localDoc['_rev'] = remoteRev;

        Response retryResponse = await _client!.put('/$docId', data: localDoc);

        if (retryResponse.statusCode == 200 ||
            retryResponse.statusCode == 201) {
          debugPrint('✅ Document updated after conflict resolution');
          return 'OK';
        } else {
          debugPrint(
              '❌ Conflict resolution failed: ${retryResponse.statusCode}');
          return 'Error: Conflict resolution failed';
        }
      } else if (getResponse.statusCode == 404) {
        debugPrint('📝 Document not found, creating new...');
        localDoc.remove('_rev');

        Response createResponse = await _client!.put('/$docId', data: localDoc);

        if (createResponse.statusCode == 200 ||
            createResponse.statusCode == 201) {
          debugPrint('✅ Document created successfully');
          return 'OK';
        } else {
          return 'Error: Failed to create document';
        }
      } else {
        return 'Error: Could not resolve conflict';
      }
    } catch (error) {
      debugPrint('❌ Error in conflict resolution: $error');
      return 'Error: $error';
    }
  }

  Future<void> refreshToken() async {
    _token = await _storage.getSessionItem("pg_admin") ?? "";

    if (_client != null && _token.isNotEmpty) {
      _client!.options.headers["Authorization"] = "Bearer $_token";
      debugPrint('🔄 Token refreshed in ComCenter');
    }
  }
}
