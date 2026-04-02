import 'storage_repository.dart';
import 'package:flutter/material.dart';

class StorageService {
  final StorageRepository _repository;

  Map<String, String> _sessionCache = {};
  Map<String, String> _localCache = {};
  bool _isInitialized = false;

  StorageService(this._repository);

  Future<void> init() async {
    if (_isInitialized) return;
    await _loadCaches();
    _isInitialized = true;
  }

  Future<void> _loadCaches() async {
    _sessionCache = await _repository.loadSession();
    _localCache = await _repository.loadLocalStorage();
    debugPrint(
        ' Storage caches loaded: ${_sessionCache.keys.length} session, ${_localCache.keys.length} local');
  }

  Future<void> reloadCaches() async {
    await _loadCaches();
  }

  String getFromSession(String key) {
    return _sessionCache[key] ?? "";
  }

  Future<String> getFromSessionAsync(String key) async {
    if (!_isInitialized) {
      debugPrint(' Storage not initialized, loading caches...');
      await _loadCaches();
      _isInitialized = true;
    }

    return _sessionCache[key] ?? "";
  }

  Future<void> setSession(String key, dynamic value) async {
    final stringValue = value is String ? value : value.toString();
    await saveSessionItem(key, stringValue);
  }

  Future<void> saveSessionItem(String key, String value) async {
    _sessionCache[key] = value;

    await _repository.saveSessionItem(key, value);

    await _loadCaches();
  }

  Future<void> removeFromSession(String key) async {
    _sessionCache.remove(key);
    await _repository.removeSessionItem(key);
  }

  Future<void> clearSession() async {
    _sessionCache.clear();
    await _repository.clearSession();
    _isInitialized = false;
  }

  String getFromLocalStorage(String key) {
    return _localCache[key] ?? "";
  }

  Future<String> getFromLocalStorageAsync(String key) async {
    if (!_isInitialized) {
      await _loadCaches();
      _isInitialized = true;
    }
    return _localCache[key] ?? "";
  }

  Future<void> setLocalStorage(String key, dynamic value) async {
    final stringValue = value is String ? value : value.toString();
    _localCache[key] = stringValue;
    await _repository.saveLocalStorageItem(key, stringValue);
    await _loadCaches();
  }

  Future<void> removeFromLocalStorage(String key) async {
    _localCache.remove(key);
    await _repository.removeLocalStorageItem(key);
  }

  Future<void> clearLocalStorage() async {
    _localCache.clear();
    await _repository.clearLocalStorage();
  }

  Future<void> clearAll() async {
    _sessionCache.clear();
    _localCache.clear();
    await _repository.clearAll();
    _isInitialized = false;
  }

  Future<bool> isLoggedIn() async {
    final empId = await getFromSessionAsync("logged_in_emp_id");
    return empId.isNotEmpty;
  }

  Map<String, String> getMultipleFromSession(List<String> keys) {
    final result = <String, String>{};
    for (final key in keys) {
      result[key] = getFromSession(key);
    }
    return result;
  }

  Future<Map<String, String>> getMultipleFromSessionAsync(
      List<String> keys) async {
    if (!_isInitialized) {
      await _loadCaches();
      _isInitialized = true;
    }

    final result = <String, String>{};
    for (final key in keys) {
      result[key] = _sessionCache[key] ?? "";
    }
    return result;
  }

  bool get isInitialized => _isInitialized;
}
