import 'package:anderson_crm_flutter/repositories/storage_repository.dart';
import 'package:flutter/material.dart';

class StorageService {
  final StorageRepository _repository;

  // Cache for quick access (loaded from repository)
  Map<String, String> _sessionCache = {};
  Map<String, String> _localCache = {};
  bool _isInitialized = false; // ✅ Track initialization state

  // StorageService(this._repository) {
  //   _init();
  // }

  // Future<void> _init() async {
  //   await _loadCaches();
  //   _isInitialized = true;

  //   // Listen for external changes (e.g., from other tabs/windows)
  //   _repository.onStorageChanged.listen((_) {
  //     _loadCaches();
  //   });
  // }

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
        '🔄 Storage caches loaded: ${_sessionCache.keys.length} session, ${_localCache.keys.length} local');
  }

  /// Force reload caches (useful after bulk operations)
  Future<void> reloadCaches() async {
    await _loadCaches();
  }

  // ========== SESSION METHODS (temporary storage) ==========

  /// Get session value synchronously (may return empty if cache not loaded)
  String getFromSession(String key) {
    return _sessionCache[key] ?? "";
  }

  /// Get session value asynchronously (ensures cache is loaded)
  Future<String> getFromSessionAsync(String key) async {
    // Ensure cache is initialized before reading
    if (!_isInitialized) {
      debugPrint('⏳ Storage not initialized, loading caches...');
      await _loadCaches();
      _isInitialized = true;
    }

    return _sessionCache[key] ?? "";
  }

  /// Set session value (legacy method name for compatibility)
  Future<void> setSession(String key, dynamic value) async {
    final stringValue = value is String ? value : value.toString();
    await saveSessionItem(key, stringValue);
  }

  /// Save session item (updates cache and persists to storage)
  Future<void> saveSessionItem(String key, String value) async {
    // Update cache immediately
    _sessionCache[key] = value;

    // Persist to repository (handles encryption in production mode)
    await _repository.saveSessionItem(key, value);

    // Reload cache to ensure sync (critical for production encrypted mode)
    await _loadCaches();
  }

  /// Remove item from session
  Future<void> removeFromSession(String key) async {
    _sessionCache.remove(key);
    await _repository.removeSessionItem(key);
  }

  /// Clear entire session
  Future<void> clearSession() async {
    _sessionCache.clear();
    await _repository.clearSession();
  }

  // ========== LOCAL STORAGE METHODS (persistent) ==========

  /// Get local storage value synchronously
  String getFromLocalStorage(String key) {
    return _localCache[key] ?? "";
  }

  /// Get local storage value asynchronously (ensures cache is loaded)
  Future<String> getFromLocalStorageAsync(String key) async {
    if (!_isInitialized) {
      await _loadCaches();
      _isInitialized = true;
    }
    return _localCache[key] ?? "";
  }

  /// Set local storage value
  Future<void> setLocalStorage(String key, dynamic value) async {
    final stringValue = value is String ? value : value.toString();
    _localCache[key] = stringValue;
    await _repository.saveLocalStorageItem(key, stringValue);
    await _loadCaches();
  }

  /// Remove item from local storage
  Future<void> removeFromLocalStorage(String key) async {
    _localCache.remove(key);
    await _repository.removeLocalStorageItem(key);
  }

  /// Clear entire local storage
  Future<void> clearLocalStorage() async {
    _localCache.clear();
    await _repository.clearLocalStorage();
  }

  // ========== UTILITY METHODS ==========

  /// Clear all storage (session + local)
  Future<void> clearAll() async {
    _sessionCache.clear();
    _localCache.clear();
    await _repository.clearAll();
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final empId = await getFromSessionAsync("logged_in_emp_id");
    return empId.isNotEmpty;
  }

  /// Get multiple session values at once
  Map<String, String> getMultipleFromSession(List<String> keys) {
    final result = <String, String>{};
    for (final key in keys) {
      result[key] = getFromSession(key);
    }
    return result;
  }

  /// Get multiple session values asynchronously
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

  /// Check if cache is ready
  bool get isInitialized => _isInitialized;
}
