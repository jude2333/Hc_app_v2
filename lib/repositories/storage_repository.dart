import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import '../config/settings.dart';

class StorageRepository {
  static const String _sessionKey = 'QiOjE2Mzc5MTI4NTYsImV4cCI6MTYzNzkxNjQ1';
  static const String _localKey = 'QiOjE2Mzc5MTI4NTYsImV4cCI6MTYzNzkxNjQ2';

  static const String _shToken =
      'eyJraWQiOiIyMDIxMTExNzA4MjAiLCJhbGciOiJSUzI1NiJ9';
  static final _key =
      encrypt.Key.fromUtf8(_shToken.substring(0, 32).padRight(32, '\x00'));
  static final _encrypter =
      encrypt.Encrypter(encrypt.AES(_key, mode: encrypt.AESMode.cbc));

  final _changeController = StreamController<void>.broadcast();
  Stream<void> get onStorageChanged => _changeController.stream;

  /// Encrypts data with a random IV and returns base64 string with IV prepended
  String _encryptData(String data) {
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypted = _encrypter.encrypt(data, iv: iv);
    // Prepend IV to encrypted data (IV is 16 bytes, encrypted data follows)
    final combined = iv.bytes + encrypted.bytes;
    return base64.encode(combined);
  }

  /// Decrypts data by extracting IV from the first 16 bytes
  String _decryptData(String encryptedData) {
    final combined = base64.decode(encryptedData);
    if (combined.length < 16) {
      throw const FormatException('Invalid encrypted data: too short');
    }

    // Extract IV (first 16 bytes) and encrypted data (remaining bytes)
    final iv = encrypt.IV(combined.sublist(0, 16));
    final encryptedBytes = combined.sublist(16);
    final encrypted = encrypt.Encrypted(encryptedBytes);

    return _encrypter.decrypt(encrypted, iv: iv);
  }

  Future<Map<String, String>> loadSession() async {
    final prefs = await SharedPreferences.getInstance();

    if (Settings.production) {
      try {
        final encrypted = prefs.getString(_sessionKey) ?? '';
        if (encrypted.isNotEmpty) {
          final decrypted = _decryptData(encrypted);
          final decoded = jsonDecode(decrypted);
          if (decoded is Map) {
            return Map<String, String>.from(decoded);
          } else {
            throw const FormatException('Session data is not a valid Map');
          }
        }
      } catch (e) {
        debugPrint("Error loading session: $e");
        // Clear corrupted session data and start fresh
        await prefs.remove(_sessionKey);
        return {};
      }
    } else {
      final keys = prefs.getKeys().where((key) =>
          key.startsWith('session_') ||
          (!key.contains('_') && key != _localKey));
      final sessionData = <String, String>{};

      for (final key in keys) {
        final value = prefs.getString(key);
        if (value != null) {
          final sessionKey =
              key.startsWith('session_') ? key.substring(8) : key;
          sessionData[sessionKey] = value;
        }
      }
      return sessionData;
    }
    return {};
  }

  Future<String?> getSessionItem(String key) async {
    final session = await loadSession();
    return session[key];
  }

  Future<String?> getLocalStorageItem(String key) async {
    final local = await loadLocalStorage();
    return local[key];
  }

  Future<Map<String, String>> loadLocalStorage() async {
    final prefs = await SharedPreferences.getInstance();
    if (Settings.production) {
      try {
        final encrypted = prefs.getString(_localKey) ?? '';
        if (encrypted.isNotEmpty) {
          final decrypted = _decryptData(encrypted);
          final decoded = jsonDecode(decrypted);
          if (decoded is Map) {
            return Map<String, String>.from(decoded);
          } else {
            throw const FormatException(
                'Local storage data is not a valid Map');
          }
        }
      } catch (e) {
        debugPrint("Error loading local storage: $e");
        // Clear corrupted local storage and start fresh
        await prefs.remove(_localKey);
        return {};
      }
    } else {
      final keys = prefs.getKeys().where((key) => key.startsWith('local_'));
      final localData = <String, String>{};

      for (final key in keys) {
        final value = prefs.getString(key);
        if (value != null) {
          localData[key.substring(6)] = value;
        }
      }
      return localData;
    }
    return {};
  }

  Future<void> saveSession(Map<String, String> sessionData) async {
    final prefs = await SharedPreferences.getInstance();

    if (Settings.production) {
      try {
        final encrypted = _encryptData(jsonEncode(sessionData));
        await prefs.setString(_sessionKey, encrypted);
      } catch (e) {
        debugPrint("Error saving session: $e");
      }
    } else {
      for (var entry in sessionData.entries) {
        await prefs.setString('session_${entry.key}', entry.value);
      }
    }
    _changeController.add(null);
  }

  Future<void> saveSessionItem(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    if (Settings.production) {
      final currentSession = await loadSession();
      currentSession[key] = value;
      await saveSession(currentSession);
    } else {
      await prefs.setString('session_$key', value);
      _changeController.add(null);
    }
  }

  Future<void> removeSessionItem(String key) async {
    final prefs = await SharedPreferences.getInstance();
    if (Settings.production) {
      final currentSession = await loadSession();
      currentSession.remove(key);
      await saveSession(currentSession);
    } else {
      await prefs.remove('session_$key');
      _changeController.add(null);
    }
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();

    if (Settings.production) {
      await prefs.remove(_sessionKey);
    } else {
      final keys = prefs
          .getKeys()
          .where((key) =>
              key.startsWith('session_') ||
              (!key.contains('_') && key != _localKey))
          .toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
    }
    _changeController.add(null);
  }

  Future<void> saveLocalStorage(Map<String, String> localData) async {
    final prefs = await SharedPreferences.getInstance();

    if (Settings.production) {
      try {
        final encrypted = _encryptData(jsonEncode(localData));
        await prefs.setString(_localKey, encrypted);
      } catch (e) {
        debugPrint("Error saving local storage: $e");
      }
    } else {
      for (var entry in localData.entries) {
        await prefs.setString('local_${entry.key}', entry.value);
      }
    }
    _changeController.add(null);
  }

  Future<void> saveLocalStorageItem(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    if (Settings.production) {
      final currentLocal = await loadLocalStorage();
      currentLocal[key] = value;
      await saveLocalStorage(currentLocal);
    } else {
      await prefs.setString('local_$key', value);
      _changeController.add(null);
    }
  }

  Future<void> removeLocalStorageItem(String key) async {
    final prefs = await SharedPreferences.getInstance();
    if (Settings.production) {
      final currentLocal = await loadLocalStorage();
      currentLocal.remove(key);
      await saveLocalStorage(currentLocal);
    } else {
      await prefs.remove('local_$key');
      _changeController.add(null);
    }
  }

  Future<void> clearLocalStorage() async {
    final prefs = await SharedPreferences.getInstance();

    if (Settings.production) {
      await prefs.remove(_localKey);
    } else {
      final keys =
          prefs.getKeys().where((key) => key.startsWith('local_')).toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
    }
    _changeController.add(null);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _changeController.add(null);
  }

  void dispose() {
    _changeController.close();
  }
}
