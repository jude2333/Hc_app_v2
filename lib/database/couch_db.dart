import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';
import 'package:anderson_crm_flutter/config/settings.dart';
import 'package:anderson_crm_flutter/repositories/storage_repository.dart';
import 'package:anderson_crm_flutter/database/postgres_db.dart';

class CouchDBClient {
  final StorageRepository _storage;
  final PostgresDB _postgresDB;

  final Map<String, Dio> _dbMap = {};
  final Map<String, Box> _hiveBoxes = {};
  final Map<String, Timer> _tokenRefreshTimers = {};
  final Map<String, StreamSubscription> _changeSubscriptions = {};

  CouchDBClient(this._storage, this._postgresDB);

  Future<Dio> getDB(String dbName) async {
    try {
      if (await _validateToken()) {
        if (_dbMap.containsKey(dbName)) {
          return _dbMap[dbName]!;
        }
      }
      return await _createDB(dbName);
    } catch (e) {
      debugPrint("Error getting CouchDB instance: $e");
      rethrow;
    }
  }

  Future<Dio> _createDB(String dbName) async {
    String remoteUrl = "${Settings.remoteCouchUrl}/$dbName";
    String token = await _getToken();
    final options = BaseOptions(
      baseUrl: remoteUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 5),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );
    final dio = Dio(options);
    _dbMap[dbName] = dio;

    _setupTokenRefresh(dio, dbName);

    debugPrint("created db for: $dbName");
    return dio;
  }

  void _setupTokenRefresh(Dio dio, String dbName) {
    _tokenRefreshTimers[dbName]?.cancel();

    _tokenRefreshTimers[dbName] =
        Timer.periodic(const Duration(minutes: 10), (timer) async {
      try {
        if (!await _validateToken()) {
          debugPrint("Token expired, refreshing for $dbName");
          String newToken = await _refreshToken();
          dio.options.headers["Authorization"] = "Bearer $newToken";
        }
      } catch (e) {
        debugPrint("Error refreshing token for $dbName: $e");
      }
    });
  }

  Future<String> _getToken() async {
    String token = await _checkAndReturnToken();
    return token;
  }

  Future<bool> _validateToken() async {
    String? expTime = await _storage.getSessionItem("exp_time");
    if (expTime == null || expTime.isEmpty) return false;

    DateTime calendar = DateFormat('yyyy-MM-dd HH:mm:ss').parse(expTime);
    calendar = calendar.subtract(const Duration(minutes: 20));
    int minutesRemaining = calendar.difference(DateTime.now()).inMinutes;
    return minutesRemaining > 0;
  }

  Future<String> _checkAndReturnToken() async {
    if (await _validateToken()) {
      String? token = await _storage.getSessionItem("pg_admin");
      return token ?? "";
    } else {
      _dbMap.clear();
      try {
        String result = await _postgresDB.refreshToken();
        if (result == "OK") {
          String? token = await _storage.getSessionItem("pg_admin");
          return token ?? "";
        }
        return "";
      } catch (e) {
        debugPrint("Error refreshing token: $e");
        return "";
      }
    }
  }

  Future<String> _refreshToken() async {
    try {
      String result = await _postgresDB.refreshToken();
      if (result == "OK") {
        String? token = await _storage.getSessionItem("pg_admin");
        return token ?? "";
      }
      return "";
    } catch (e) {
      debugPrint("Error refreshing token: $e");
      return "";
    }
  }

  void dispose() {
    for (var timer in _tokenRefreshTimers.values) {
      timer.cancel();
    }
    _tokenRefreshTimers.clear();

    for (var subscription in _changeSubscriptions.values) {
      subscription.cancel();
    }
    _changeSubscriptions.clear();

    for (var db in _dbMap.values) {
      db.close();
    }
    _dbMap.clear();

    for (var box in _hiveBoxes.values) {
      box.close();
    }
    _hiveBoxes.clear();
  }
}
