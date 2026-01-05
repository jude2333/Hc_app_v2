import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../config/settings.dart';
import '../repositories/storage_repository.dart';

class DBHandler {
  final StorageRepository _storage;

  final void Function(String)? onTodayChange;
  final void Function()? onWorkOrderChange;
  final void Function()? onNotificationChange;

  final Map<String, Box> _dbMap = {};
  final Map<String, Dio> _remoteClients = {};
  final Map<String, Timer> _syncTimers = {};
  final Map<String, StreamController> _changeNotifiers = {};
  final Map<String, Timer> _changeListenerTimers = {};
  final Map<String, Set<String>> _pendingPushes = {};

  bool _creating = false;
  String _token = "";
  List<String>? _dbNames;
  int _retryDelay = 5000;

  final Map<String, String> _lastSequences = {};
  final Map<String, Map<String, String>> _documentRevisions = {};

  final _workOrderRefreshBus = StreamController<void>.broadcast();
  Stream<void> get workOrderRefreshStream => _workOrderRefreshBus.stream;

  final _notificationRefreshBus = StreamController<void>.broadcast();
  Stream<void> get notificationRefreshStream => _notificationRefreshBus.stream;

  bool _isSyncActive = true;

  DBHandler(
    this._storage, {
    this.onTodayChange,
    this.onWorkOrderChange,
    this.onNotificationChange,
  });

  void stopSync() {
    debugPrint("🛑 Stopping CouchDB Sync...");
    _isSyncActive = false;
  }

  Future<String> init() async {
    if (_creating) return "ALREADY_CREATING";

    _creating = true;

    try {
      debugPrint("DB Handler init starting...");

      _dbNames = [
        "last_updated_at",
        "price_list",
        "com_center",
        "temp_db",
        "login_log",
        "dashboard"
      ];

      String? centerBasedDB = await _storage.getSessionItem("doc_dbs");
      // String? delDocDBs = await _storage.getSessionItem("del_doc_dbs");

      if (centerBasedDB != null && centerBasedDB.isNotEmpty) {
        _dbNames!.addAll(centerBasedDB.split(","));
      }

      String token = await _getToken();
      // await _setUp(token);

      _creating = false;
      return "OK";
    } catch (error) {
      debugPrint("Init Error: $error");
      _creating = false;
      throw "InitError: $error";
    }
  }

  String? resolveName(String name) {
    if (_dbNames == null) return null;

    for (String dbName in _dbNames!) {
      if (dbName.endsWith(name)) {
        return dbName;
      }
    }
    return null;
  }

  int getDbCount() {
    return _dbMap.length;
  }

  Future<Box?> getDb(String name) async {
    String? dbName = resolveName(name);

    if (dbName != null && _dbMap.containsKey(dbName)) {
      return _dbMap[dbName];
    }

    String result = await _setUpDBWithTime();
    if (result == "OK" && dbName != null && _dbMap.containsKey(dbName)) {
      return _dbMap[dbName];
    }

    return null;
  }

  Future<String> _setUpDBWithTime() async {
    try {
      await init();

      Box? timeBox = _dbMap["last_updated_at"];
      if (timeBox != null) {
        var timeDoc = timeBox.get("last:updated_time");
        if (timeDoc != null) {
          String today = timeDoc['time'] ?? DateTime.now().toIso8601String();
          onTodayChange?.call(today);
          return "OK";
        }
      }
      return "ERROR: No time document found";
    } catch (error) {
      debugPrint("Error in _setUpDBWithTime: $error");
      return "ERROR: $error";
    }
  }

  // Future<void> _setUp(String token) async {
  //   await _cleanup();

  //   if (_dbNames == null) return;

  //   _token = token;

  //   for (String dbName in _dbNames!) {
  //     String departmentName =
  //         await _storage.getSessionItem("department_name") ?? "";
  //     String roleName = await _storage.getSessionItem("role_name") ?? "";

  //     if (departmentName == "HOME COLLECTION" &&
  //         roleName == "TECHNICIAN" &&
  //         dbName == "pin_codes") {
  //       continue;
  //     }

  //     await _createDatabase(token, dbName);
  //   }
  // }

  Future<void> _createDatabase(String token, String dbName) async {
    try {
      // 1. Create local Hive database
      Box box = await Hive.openBox(dbName);
      _dbMap[dbName] = box;

      _pendingPushes[dbName] = <String>{};

      // 3. Create remote CouchDB client
      String remoteUrl = "${Settings.remoteCouchUrl}/$dbName";
      final dio = Dio(BaseOptions(
        baseUrl: remoteUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      ));
      _remoteClients[dbName] = dio;

      // 4. Initialize change notifier
      _changeNotifiers[dbName] = StreamController.broadcast();

      // 5. Initialize document revision tracking
      _documentRevisions[dbName] = {};

      // 6. Set up sync based on database type
      await _setupSyncForDatabase(dbName);

      // 7. Start change listener
      _startChangeListener(dbName);
    } catch (error) {
      await retrySetup(dbName);
    }
  }

  Stream<List<Map<String, dynamic>>> workOrderStream() async* {
    await init();
    final woDb = resolveName('work_orders')!;
    yield* getChangeStream(woDb)!.asyncMap((_) async {
      final list = await getAllDocuments(woDb);
      final empIdStr = await _storage.getSessionItem('logged_in_emp_id') ?? '';
      final empId = int.tryParse(empIdStr);
      return list.where((doc) => doc['assigned_id'] == empId).toList();
    }).handleError((e, s) => debugPrint('workOrderStream error: $e'));
  }

  Stream<List<Map<String, dynamic>>> notificationStream() async* {
    await init();
    final dbName = resolveName('hc_notifications');
    if (dbName == null) {
      yield <Map<String, dynamic>>[];
      return;
    }
    yield await getAllDocuments(dbName);
    await for (final _ in getChangeStream(dbName) ?? Stream.empty()) {
      yield await getAllDocuments(dbName);
    }
  }

  Future<void> _setupSyncForDatabase(String dbName) async {
    String departmentName =
        await _storage.getSessionItem("department_name") ?? "";
    String roleName = await _storage.getSessionItem("role_name") ?? "";

    if (dbName == "temp_db" ||
        dbName == "login_log" ||
        dbName == "com_center") {
      _startSync(dbName, SyncType.pushOnly);
    } else if (dbName == "pin_codes" || dbName == "last_updated_at") {
      _startSync(dbName, SyncType.pullOnly);
    } else if (dbName.contains("work_orders")) {
      if (departmentName == "HOME COLLECTION" && roleName == "TECHNICIAN") {
        String empIdStr =
            await _storage.getSessionItem("logged_in_emp_id") ?? "0";
        int empId = int.tryParse(empIdStr) ?? 0;
        _startFilteredSync(dbName, "assigned_id", empId);
      } else {
        _startSync(dbName, SyncType.bidirectional);
      }
    } else if (dbName.contains("price_list")) {
      if (roleName == "MANAGER") {
        _startSync(dbName, SyncType.bidirectional);
      } else {
        _startSync(dbName, SyncType.pullOnly);
      }
    } else if (dbName.contains("hc_notifications")) {
      String empIdStr =
          await _storage.getSessionItem("logged_in_emp_id") ?? "0";
      int empId = int.tryParse(empIdStr) ?? 0;
      _startFilteredSync(dbName, "to_id", empId);
    } else {
      _startSync(dbName, SyncType.bidirectional);
    }
  }

  void _startSync(String dbName, SyncType syncType) {
    _syncTimers[dbName] = Timer.periodic(
      const Duration(seconds: 30),
      (timer) async {
        try {
          switch (syncType) {
            case SyncType.pushOnly:
              await _replicateToRemote(dbName);
              break;
            case SyncType.pullOnly:
              await _replicateFromRemote(dbName);
              break;
            case SyncType.bidirectional:
              await _replicateToRemote(dbName);
              await _replicateFromRemote(dbName);
              break;
          }
          _retryDelay = 5000;
        } catch (error) {
          debugPrint("Sync error for $dbName: $error");
          _handleSyncError(dbName, error);
        }
      },
    );
  }

  Stream<Map<String, dynamic>> startContinuousStream(String dbName) async* {
    String? resolvedName = resolveName(dbName);
    if (resolvedName == null) return;

    String token = await _getToken();
    String remoteUrl = "${Settings.remoteCouchUrl}/$resolvedName";

    Dio pollingClient = Dio(BaseOptions(
      baseUrl: remoteUrl,
      headers: {"Authorization": "Bearer $token", "Accept": "application/json"},
      connectTimeout: const Duration(seconds: 40),
      receiveTimeout: const Duration(seconds: 40),
    ));

    String currentSeq = 'now';
    _isSyncActive = true;

    debugPrint("🔌 Connected to Real-time Feed (Long Poll Mode)");

    while (_isSyncActive) {
      try {
        Response response = await pollingClient.get(
          '/_changes',
          queryParameters: {
            'feed': 'longpoll',
            'heartbeat': 10000,
            'include_docs': 'true',
            'since': currentSeq,
            'timeout': 30000,
          },
        );

        if (response.statusCode == 200 && response.data != null) {
          final data = response.data;

          if (data['last_seq'] != null) {
            currentSeq = data['last_seq'].toString();
          }

          final List<dynamic> results = data['results'] ?? [];

          if (results.isNotEmpty) {
            debugPrint("⚡ RECEIVED ${results.length} UPDATES");
            for (var row in results) {
              yield Map<String, dynamic>.from(row);
            }
          }
        }
      } catch (e) {
        if (e is DioException &&
            (e.type == DioExceptionType.receiveTimeout ||
                e.type == DioExceptionType.connectionTimeout)) {
          continue;
        }

        debugPrint("⚠️ Connection interrupted: $e");

        if (_isSyncActive) {
          await Future.delayed(const Duration(seconds: 5));
        }
      }

      await Future.delayed(const Duration(milliseconds: 50));
    }

    debugPrint("🛑 Sync Loop Terminated.");
  }

  void _startFilteredSync(String dbName, String filterField, int filterValue) {
    _syncTimers[dbName]?.cancel();
    Timer.run(() async {
      try {
        await _pushFilteredChangesToRemote(dbName, filterField, filterValue);
        await _pullFilteredChangesFromRemote(dbName, filterField, filterValue);
      } catch (error) {
        debugPrint("Initial filtered sync error for $dbName: $error");
      }
    });

    _syncTimers[dbName] = Timer.periodic(
      const Duration(seconds: 30),
      (timer) async {
        try {
          await _pushFilteredChangesToRemote(dbName, filterField, filterValue);
          await _pullFilteredChangesFromRemote(
              dbName, filterField, filterValue);
          _retryDelay = 5000;
        } catch (error) {
          _handleSyncError(dbName, error);
        }
      },
    );
  }

  Future<void> _replicateFromRemote(String dbName) async {
    if (!_remoteClients.containsKey(dbName) || !_dbMap.containsKey(dbName)) {
      return;
    }

    Dio dio = _remoteClients[dbName]!;
    // Box box = _dbMap[dbName]!;
    String lastSeq = _lastSequences[dbName] ?? "0";

    try {
      Response response = await dio.get("/_changes", queryParameters: {
        "since": lastSeq,
        "include_docs": true,
        "limit": 100,
      });

      if (response.statusCode == 200) {
        Map<String, dynamic> data = response.data;
        List<dynamic> results = data['results'] ?? [];

        if (data['last_seq'] != null) {
          _lastSequences[dbName] = data['last_seq'].toString();
        }

        if (dbName.contains('work_orders') && results.isNotEmpty) {
          _workOrderRefreshBus.add(null);
        }

        if (dbName.contains('hc_notifications') && results.isNotEmpty) {
          _notificationRefreshBus.add(null);
        }
      }
    } catch (error) {
      if (error is DioException) {
        debugPrint("Response: ${error.response?.data}");
      }
    }
  }

  Future<void> _replicateToRemote(String dbName) async {
    if (!_dbMap.containsKey(dbName) || !_remoteClients.containsKey(dbName)) {
      return;
    }

    Box box = _dbMap[dbName]!;
    Dio dio = _remoteClients[dbName]!;

    Set<String>? pendingIds = _pendingPushes[dbName];
    if (pendingIds == null || pendingIds.isEmpty) return;

    debugPrint('Pushing ${pendingIds.length} pending changes for $dbName');
    final idsToProcess = Set<String>.from(pendingIds);
    _pendingPushes[dbName]!.clear();

    bool somethingPushed = false;

    for (String docId in idsToProcess) {
      Map<String, dynamic>? doc;

      try {
        dynamic docData = box.get(docId);
        if (docData == null) continue;

        doc = Map<String, dynamic>.from(docData);
        doc['_id'] = docId;
        doc.remove('_local_modified');

        Response response = await dio.put(
          '/$docId',
          data: doc,
          options: Options(validateStatus: (s) => s! < 500),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          doc['_rev'] = response.data['rev'];
          doc.remove('_local_modified');
          await box.put(docId, doc);
          _updateDocumentRevision(dbName, docId, doc['_rev']!);
          somethingPushed = true;
        } else if (response.statusCode == 409) {
          await _resolveConflict(dbName, docId, doc);
        } else {
          _pendingPushes[dbName]!.add(docId);
        }
      } catch (error) {
        _pendingPushes[dbName]!.add(docId);

        if (error is DioException &&
            error.response?.statusCode == 409 &&
            doc != null) {
          await _resolveConflict(dbName, docId, doc);
        }
      }
    }
    if (dbName.contains('work_orders') && somethingPushed) {
      _workOrderRefreshBus.add(null);
    }
    if (dbName.contains('hc_notifications') && somethingPushed) {
      _notificationRefreshBus.add(null);
    }
  }

  Future<void> _pushFilteredChangesToRemote(
      String dbName, String filterField, int filterValue) async {
    if (!_dbMap.containsKey(dbName) || !_remoteClients.containsKey(dbName)) {
      return;
    }

    Box box = _dbMap[dbName]!;
    Dio dio = _remoteClients[dbName]!;

    List<String> keys = box.keys.cast<String>().toList();

    for (String key in keys) {
      dynamic docData = box.get(key);
      if (docData == null) continue;

      Map<String, dynamic> doc = Map<String, dynamic>.from(docData);

      if (doc[filterField] == filterValue && _needsPush(doc, dbName, key)) {
        try {
          if (!doc.containsKey('_id')) {
            doc['_id'] = key;
          }

          Response response = await dio.put("/$key", data: doc);

          if (response.statusCode == 200 || response.statusCode == 201) {
            doc['_rev'] = response.data['rev'];
            doc.remove('_local_modified');
            await box.put(key, doc);
            _updateDocumentRevision(dbName, key, doc['_rev']);
          }
        } catch (error) {
          if (error is DioException && error.response?.statusCode == 409) {
            await _resolveConflict(dbName, key, doc);
          }
        }
      }
    }
  }

  Future<void> _pullFilteredChangesFromRemote(
      String dbName, String filterField, int filterValue) async {
    if (!_remoteClients.containsKey(dbName)) return;

    Dio dio = _remoteClients[dbName]!;
    Box box = _dbMap[dbName]!;
    String lastSeq = _lastSequences[dbName] ?? "0";

    try {
      Response response = await dio.get("/_changes", queryParameters: {
        "since": lastSeq,
        "include_docs": true,
        "limit": 100,
      });

      if (response.statusCode == 200) {
        Map<String, dynamic> data = response.data;
        List<dynamic> results = data['results'] ?? [];

        for (var change in results) {
          String docId = change['id'];
          Map<String, dynamic>? doc = change['doc'];
          bool deleted = change['deleted'] ?? false;

          if (doc != null) {
            dynamic fieldValue = doc[filterField];
            bool matches = false;
            if (fieldValue is int) {
              matches = fieldValue == filterValue;
            } else if (fieldValue is String) {
              matches = int.tryParse(fieldValue) == filterValue;
            }

            if (matches) {
              if (deleted) {
                await box.delete(docId);
              } else {
                await box.put(docId, doc);
                _updateDocumentRevision(dbName, docId, doc['_rev']);
              }
              _notifyChange(dbName, docId, doc, deleted);
            }
          }
        }

        if (data['last_seq'] != null) {
          _lastSequences[dbName] = data['last_seq'].toString();
        }
      }
    } catch (error) {
      if (error is DioException) {
        debugPrint("Response: ${error.response?.data}");
      }
    }
  }

  void _startChangeListener(String dbName) {
    // _changeListenerTimers[dbName] =
    //     Timer.periodic(const Duration(seconds: 15), (timer) async {
    //   try {
    //     await _checkForChanges(dbName);
    //   } catch (error) {
    //   }
    // });
  }

  void _notifyChange(
      String dbName, String docId, Map<String, dynamic>? doc, bool deleted) {
    try {
      if (docId.startsWith("work_order:")) {
        onWorkOrderChange?.call();
      } else if (docId.startsWith("last:updated_time")) {
        if (doc != null && doc.containsKey('time')) {
          onTodayChange?.call(doc['time']);
        }
      } else if (docId.startsWith("notifications:")) {
        onNotificationChange?.call();
      }

      if (_changeNotifiers.containsKey(dbName)) {
        _changeNotifiers[dbName]!.add({
          'id': docId,
          'doc': doc,
          'deleted': deleted,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }
    } catch (e) {
      debugPrint("❌ Error in _notifyChange: $e");
    }
  }

  Future<void> _handleSyncError(String dbName, dynamic error) async {
    debugPrint("Handling sync error for $dbName: $error");

    _retryDelay = min(_retryDelay * 2, 60000);

    await Future.delayed(Duration(milliseconds: _retryDelay));

    if (_retryDelay > 30000) {
      await retrySetup(dbName);
    }
  }

  Future<void> retrySetup(String dbName) async {
    try {
      _syncTimers[dbName]?.cancel();
      _changeListenerTimers[dbName]?.cancel();
      _changeNotifiers[dbName]?.close();
      _remoteClients[dbName]?.close();

      if (_dbMap.containsKey(dbName)) {
        await _dbMap[dbName]!.close();
        await Hive.deleteBoxFromDisk(dbName);
      }

      _dbMap.remove(dbName);
      _remoteClients.remove(dbName);
      _syncTimers.remove(dbName);
      _changeListenerTimers.remove(dbName);
      _changeNotifiers.remove(dbName);
      _lastSequences.remove(dbName);
      _documentRevisions.remove(dbName);

      await _createDatabase(_token, dbName);
    } catch (error) {
      // debugPrint("Retry setup failed for $dbName: $error");
    }
  }

  String? _getDocumentRevision(String dbName, String docId) {
    return _documentRevisions[dbName]?[docId];
  }

  void _updateDocumentRevision(String dbName, String docId, String? revision) {
    if (revision != null) {
      _documentRevisions[dbName] ??= {};
      _documentRevisions[dbName]![docId] = revision;
    }
  }

  Future<String> _getToken() async {
    if (_token.isNotEmpty) return _token;
    await _refreshToken();
    return _token;
  }

  Future<void> _refreshToken() async {
    try {
      _token = await _storage.getSessionItem("pg_admin") ?? "";
    } catch (error) {
      rethrow;
    }
  }

  Future<void> _cleanup() async {
    for (Timer timer in _syncTimers.values) {
      timer.cancel();
    }

    for (Timer timer in _changeListenerTimers.values) {
      timer.cancel();
    }

    for (StreamController controller in _changeNotifiers.values) {
      await controller.close();
    }

    for (Dio dio in _remoteClients.values) {
      dio.close();
    }

    for (Box box in _dbMap.values) {
      await box.close();
    }

    _syncTimers.clear();
    _changeListenerTimers.clear();
    _changeNotifiers.clear();
    _remoteClients.clear();
    _dbMap.clear();
    _lastSequences.clear();
    _documentRevisions.clear();
  }

  Future<void> dispose() async {
    await _cleanup();
    _creating = false;
    _token = "";
    _dbNames = null;
  }

  Stream<Map<String, dynamic>>? getChangeStream(String dbName) {
    String? resolvedName = resolveName(dbName);
    if (resolvedName != null && _changeNotifiers.containsKey(resolvedName)) {
      return _changeNotifiers[resolvedName]!
          .stream
          .cast<Map<String, dynamic>>();
    }
    return null;
  }

  Future<Map<String, dynamic>?> getDocument(String dbName, String docId) async {
    String? resolvedName = resolveName(dbName);
    if (resolvedName != null && _dbMap.containsKey(resolvedName)) {
      dynamic doc = _dbMap[resolvedName]!.get(docId);
      if (doc != null) {
        return Map<String, dynamic>.from(doc);
      }
    }
    return null;
  }

  Future<void> putDocument(
      String dbName, String docId, Map<String, dynamic> doc) async {
    String? resolvedName = resolveName(dbName);
    if (resolvedName == null || !_dbMap.containsKey(resolvedName)) {
      debugPrint("❌ putDocument failed: database not found for $dbName");
      return;
    }

    debugPrint("📝 Putting document: $docId in $resolvedName");

    try {
      doc['_local_modified'] = true;
      doc['_id'] = docId;

      await _dbMap[resolvedName]!.put(docId, doc);

      _pendingPushes[resolvedName] ??= <String>{};
      _pendingPushes[resolvedName]!.add(docId);

      _notifyChange(resolvedName, docId, doc, false);
    } catch (e) {
      debugPrint("❌ Error in putDocument for $docId: $e");
    }
  }

  Future<void> deleteDocument(String dbName, String docId) async {
    String? resolvedName = resolveName(dbName);
    if (resolvedName == null || !_dbMap.containsKey(resolvedName)) {
      return;
    }

    await _dbMap[resolvedName]!.delete(docId);

    _pendingPushes[resolvedName] ??= <String>{};
    _pendingPushes[resolvedName]!.add(docId);

    _notifyChange(resolvedName, docId, null, true);
  }

  List<String> getAllDocumentIds(String dbName) {
    String? resolvedName = resolveName(dbName);
    if (resolvedName != null && _dbMap.containsKey(resolvedName)) {
      return _dbMap[resolvedName]!.keys.cast<String>().toList();
    }
    return [];
  }

  Map<String, dynamic> getSyncStatus() {
    return {
      'databases': _dbMap.keys.toList(),
      'activeTimers': _syncTimers.length,
      'retryDelay': _retryDelay,
      'lastSequences': Map<String, String>.from(_lastSequences),
      'documentCounts': _dbMap.map((key, box) => MapEntry(key, box.length)),
    };
  }

  Future<void> forceSync(String dbName) async {
    debugPrint("🔄 Force sync requested for: $dbName");

    String? resolvedName = resolveName(dbName);
    if (resolvedName == null) {
      debugPrint("❌ Database not found: $dbName");
      return;
    }

    try {
      debugPrint("🔄 Starting force sync for: $resolvedName");

      int pendingCount = _pendingPushes[resolvedName]?.length ?? 0;
      debugPrint("📊 Pending pushes before sync: $pendingCount");
      if (pendingCount > 0) {
        debugPrint("📋 Pending IDs: ${_pendingPushes[resolvedName]}");
      }

      debugPrint("⬆️ Starting push for: $resolvedName");
      await _replicateToRemote(resolvedName);
      debugPrint("✅ Push completed for: $resolvedName");

      int remainingCount = _pendingPushes[resolvedName]?.length ?? 0;
      debugPrint("📊 Remaining pending pushes: $remainingCount");

      debugPrint("⬇️ Starting pull for: $resolvedName");
      await _replicateFromRemote(resolvedName);
      debugPrint("✅ Pull completed for: $resolvedName");

      debugPrint("✅ Force sync completed successfully for: $resolvedName");
    } catch (e, stackTrace) {
      debugPrint("❌ Force sync error for $resolvedName: $e");
      debugPrint("Stack trace: $stackTrace");
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getAllDocuments(String dbName) async {
    String? resolvedName = resolveName(dbName);
    if (resolvedName == null || !_dbMap.containsKey(resolvedName)) {
      return [];
    }

    Box box = _dbMap[resolvedName]!;
    List<Map<String, dynamic>> docs = [];

    for (String key in box.keys.cast<String>()) {
      dynamic doc = box.get(key);
      if (doc != null) {
        docs.add(Map<String, dynamic>.from(doc));
      }
    }

    return docs;
  }

  bool hasDocument(String dbName, String docId) {
    String? resolvedName = resolveName(dbName);
    if (resolvedName == null || !_dbMap.containsKey(resolvedName)) {
      return false;
    }

    return _dbMap[resolvedName]!.containsKey(docId);
  }

  String? getLastSyncSequence(String dbName) {
    String? resolvedName = resolveName(dbName);
    if (resolvedName == null) return null;

    return _lastSequences[resolvedName];
  }

  Future<void> clearLocalDatabase(String dbName) async {
    String? resolvedName = resolveName(dbName);
    if (resolvedName == null || !_dbMap.containsKey(resolvedName)) {
      return;
    }

    Box box = _dbMap[resolvedName]!;
    await box.clear();
    _documentRevisions[resolvedName]?.clear();
    debugPrint("Cleared local database: $resolvedName");
  }

  Map<String, dynamic> getDetailedSyncStats() {
    Map<String, dynamic> stats = {};

    for (String dbName in _dbMap.keys) {
      Box box = _dbMap[dbName]!;
      List<String> keys = box.keys.cast<String>().toList();

      int localModifiedCount = 0;
      int totalCount = keys.length;

      for (String key in keys) {
        dynamic doc = box.get(key);
        if (doc != null && doc['_local_modified'] == true) {
          localModifiedCount++;
        }
      }

      stats[dbName] = {
        'totalDocuments': totalCount,
        'localModified': localModifiedCount,
        'lastSequence': _lastSequences[dbName] ?? 'unknown',
        'hasActiveSync': _syncTimers.containsKey(dbName),
        'hasChangeListener': _changeListenerTimers.containsKey(dbName),
      };
    }

    return stats;
  }

  bool isSyncing(String dbName) {
    String? resolvedName = resolveName(dbName);
    if (resolvedName == null) return false;

    return _syncTimers.containsKey(resolvedName) &&
        _syncTimers[resolvedName]!.isActive;
  }

  void pauseSync(String dbName) {
    String? resolvedName = resolveName(dbName);
    if (resolvedName == null) return;

    _syncTimers[resolvedName]?.cancel();
    _changeListenerTimers[resolvedName]?.cancel();
    debugPrint("Paused sync for: $resolvedName");
  }

  Future<void> resumeSync(String dbName) async {
    String? resolvedName = resolveName(dbName);
    if (resolvedName == null) return;

    await _setupSyncForDatabase(resolvedName);
    _startChangeListener(resolvedName);
    debugPrint("Resumed sync for: $resolvedName");
  }

  Future<List<String>> getConflictedDocuments(String dbName) async {
    List<String> conflicted = [];
    String? resolvedName = resolveName(dbName);
    if (resolvedName == null || !_dbMap.containsKey(resolvedName)) {
      return conflicted;
    }

    Box box = _dbMap[resolvedName]!;
    Dio? dio = _remoteClients[resolvedName];
    if (dio == null) return conflicted;

    for (String key in box.keys.cast<String>()) {
      dynamic localDoc = box.get(key);
      if (localDoc != null && localDoc['_local_modified'] == true) {
        try {
          Response response = await dio.get("/$key");
          if (response.statusCode == 200) {
            Map<String, dynamic> remoteDoc = response.data;
            if (remoteDoc['_rev'] != localDoc['_rev']) {
              conflicted.add(key);
            }
          }
        } catch (e) {
          // Document might not exist remotely yet
        }
      }
    }

    return conflicted;
  }

  Future<void> resolveConflictWithLocal(String dbName, String docId) async {
    String? resolvedName = resolveName(dbName);
    if (resolvedName == null || !_dbMap.containsKey(resolvedName)) {
      return;
    }

    Box box = _dbMap[resolvedName]!;
    Dio? dio = _remoteClients[resolvedName];
    if (dio == null) return;

    dynamic localDoc = box.get(docId);
    if (localDoc != null) {
      Map<String, dynamic> doc = Map<String, dynamic>.from(localDoc);

      try {
        Response response = await dio.get("/$docId");
        if (response.statusCode == 200) {
          Map<String, dynamic> remoteDoc = response.data;
          doc['_rev'] = remoteDoc['_rev'];
        }

        Response putResponse = await dio.put("/$docId", data: doc);
        if (putResponse.statusCode == 200 || putResponse.statusCode == 201) {
          doc['_rev'] = putResponse.data['rev'];
          doc.remove('_local_modified');
          await box.put(docId, doc);
          _updateDocumentRevision(resolvedName, docId, doc['_rev']);
          debugPrint("Resolved conflict for $docId with local version");
        }
      } catch (e) {
        debugPrint("Error resolving conflict for $docId: $e");
      }
    }
  }

  Map<String, dynamic> getDatabaseMetadata(String dbName) {
    String? resolvedName = resolveName(dbName);
    if (resolvedName == null || !_dbMap.containsKey(resolvedName)) {
      return {};
    }

    Box box = _dbMap[resolvedName]!;
    List<String> keys = box.keys.cast<String>().toList();

    Map<String, int> docTypeCount = {};
    for (String key in keys) {
      String prefix = key.split(':').first;
      docTypeCount[prefix] = (docTypeCount[prefix] ?? 0) + 1;
    }

    return {
      'name': resolvedName,
      'documentCount': box.length,
      'documentTypes': docTypeCount,
      'isOpen': box.isOpen,
      'path': box.path,
      'lastSequence': _lastSequences[resolvedName],
      'hasPendingChanges': _checkForPendingChanges(resolvedName),
    };
  }

  bool _checkForPendingChanges(String dbName) {
    if (!_dbMap.containsKey(dbName)) return false;

    Box box = _dbMap[dbName]!;
    for (String key in box.keys.cast<String>()) {
      dynamic doc = box.get(key);
      if (doc != null && doc['_local_modified'] == true) {
        return true;
      }
    }
    return false;
  }

  Future<String> exportDatabase(String dbName) async {
    String? resolvedName = resolveName(dbName);
    if (resolvedName == null || !_dbMap.containsKey(resolvedName)) {
      return "{}";
    }

    Box box = _dbMap[resolvedName]!;
    Map<String, dynamic> exportData = {};

    for (String key in box.keys.cast<String>()) {
      dynamic doc = box.get(key);
      if (doc != null) {
        exportData[key] = Map<String, dynamic>.from(doc);
      }
    }

    return jsonEncode(exportData);
  }

  Future<void> importDatabase(String dbName, String jsonData) async {
    String? resolvedName = resolveName(dbName);
    if (resolvedName == null || !_dbMap.containsKey(resolvedName)) {
      return;
    }

    try {
      Map<String, dynamic> importData = jsonDecode(jsonData);
      Box box = _dbMap[resolvedName]!;

      for (var entry in importData.entries) {
        await box.put(entry.key, entry.value);
      }

      debugPrint("Imported ${importData.length} documents to $resolvedName");
    } catch (e) {
      debugPrint("Error importing database $dbName: $e");
    }
  }

  Future<Map<String, bool>> healthCheck() async {
    Map<String, bool> health = {};

    for (String dbName in _remoteClients.keys) {
      Dio dio = _remoteClients[dbName]!;
      try {
        Response response = await dio.get("/");
        health[dbName] = response.statusCode == 200;
      } catch (e) {
        health[dbName] = false;
      }
    }

    return health;
  }

  bool _needsPush(Map<String, dynamic> doc, String dbName, String docId) {
    if (doc['_local_modified'] == true) return true;
    if (!doc.containsKey('_rev')) return true;

    String? trackedRev = _getDocumentRevision(dbName, docId);
    if (trackedRev == null || trackedRev != doc['_rev']) return true;

    return false;
  }

  Future<void> _resolveConflict(
      String dbName, String docId, Map<String, dynamic> localDoc) async {
    try {
      Dio dio = _remoteClients[dbName]!;

      Response response = await dio.get("/$docId");
      if (response.statusCode == 200) {
        Map<String, dynamic> remoteDoc = response.data;

        Box box = _dbMap[dbName]!;
        await box.put(docId, remoteDoc);
        _updateDocumentRevision(dbName, docId, remoteDoc['_rev']);

        _notifyChange(dbName, docId, remoteDoc, false);
      }
    } catch (error) {
      debugPrint("Error resolving conflict for $docId: $error");
    }
  }
}

enum SyncType {
  pushOnly,
  pullOnly,
  bidirectional,
}
