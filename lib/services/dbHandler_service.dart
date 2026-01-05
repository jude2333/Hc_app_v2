import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../database/db_handler.dart';
import 'package:anderson_crm_flutter/providers/db_handler_provider.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';

class DBHandlerService {
  final Ref ref;

  DBHandlerService(this.ref);

  DBHandler get _db => ref.read(dbHandlerProvider);

  Future<dynamic> init() async {
    return await _db.init();
  }

  String? resolveName(String name) {
    return _db.resolveName(name);
  }

  int getDbCount() {
    return _db.getDbCount();
  }

  Future<Box?> getDb(String name) async {
    return await _db.getDb(name);
  }

  Future<void> retrySetup(String dbName) async {
    return await _db.retrySetup(dbName);
  }

  Future<String> setUpDBWithTime() async {
    try {
      final result = await init();
      return result == "OK" ? "OK" : "ERROR";
    } catch (e) {
      return "ERROR: $e";
    }
  }

  Stream<Map<String, dynamic>> startContinuousStream(String dbName) {
    return _db.startContinuousStream(dbName);
  }

  Stream<List<Map<String, dynamic>>> workOrderStream() {
    return _db.workOrderStream();
  }

  Future<String> getToken() async {
    return await _getTokenWrapper();
  }

  Future<void> refreshToken() async {
    await _refreshTokenWrapper();
  }

  Future<void> deleteDB(String dbName) async {
    throw UnimplementedError(
        'deleteDB method needs to be made public in DBHandler class');
  }

  Future<void> setupDatabase(String token, String dbName) async {
    throw UnimplementedError(
        'setupDatabase method needs DBHandler._create to be made public');
  }

  void setupReplication(String direction, String dbName) {
    throw UnimplementedError(
        'setupReplication method needs DBHandler replication methods to be made public');
  }

  void setupFilteredReplication(
      String filterField, int filterValue, String dbName) {
    throw UnimplementedError(
        'setupFilteredReplication method needs DBHandler filtered replication methods to be made public');
  }

  void setupChangesListener(String dbName) {
    throw UnimplementedError(
        'setupChangesListener method needs DBHandler changes methods to be made public');
  }

  Future<void> dispose() async {
    await _db.dispose();
  }

  Future<String> _getTokenWrapper() async {
    try {
      final storage = ref.read(storageServiceProvider);
      String token = storage.getFromSession("pg_admin") ?? "";
      if (token.isEmpty) {
        await _refreshTokenWrapper();
        token = storage.getFromSession("pg_admin") ?? "";
      }
      return token;
    } catch (e) {
      throw 'Error getting token: $e';
    }
  }

  Future<void> _refreshTokenWrapper() async {
    try {
      final storage = ref.read(storageServiceProvider);
      String token = storage.getFromSession("pg_admin") ?? "";
    } catch (e) {
      throw 'Error refreshing token: $e';
    }
  }

  bool isDatabaseInitialized() {
    return _db.getDbCount() > 0;
  }

  Map<String, dynamic> getDatabaseStatus() {
    return {
      'initialized': isDatabaseInitialized(),
      'database_count': getDbCount(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}

final dbHandlerServiceProvider = Provider<DBHandlerService>((ref) {
  return DBHandlerService(ref);
});
