import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationCacheService {
  static const String _cacheKey = 'tracking_cached_pings';
  static const int _maxCacheSize = 500;

  static Future<void> cachePing(Map<String, dynamic> ping) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getStringList(_cacheKey) ?? [];

      cached.add(jsonEncode(ping));

      if (cached.length > _maxCacheSize) {
        cached.removeRange(0, cached.length - _maxCacheSize);
      }

      await prefs.setStringList(_cacheKey, cached);
      debugPrint('[LocationCache] Cached ping (${cached.length} total)');
    } catch (e) {
      debugPrint('[LocationCache] Cache error: $e');
    }
  }

  static Future<void> cachePings(List<Map<String, dynamic>> pings) async {
    if (pings.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getStringList(_cacheKey) ?? [];

      for (final ping in pings) {
        cached.add(jsonEncode(ping));
      }

      if (cached.length > _maxCacheSize) {
        cached.removeRange(0, cached.length - _maxCacheSize);
      }

      await prefs.setStringList(_cacheKey, cached);
      debugPrint(
          '[LocationCache] Cached ${pings.length} pings in batch (${cached.length} total)');
    } catch (e) {
      debugPrint('[LocationCache] Batch cache error: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> peekCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getStringList(_cacheKey) ?? [];

      if (cached.isEmpty) return [];

      return cached
          .map((s) {
            try {
              return jsonDecode(s) as Map<String, dynamic>;
            } catch (_) {
              return null;
            }
          })
          .where((p) => p != null)
          .cast<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      debugPrint('[LocationCache] Peek error: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> drainCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getStringList(_cacheKey) ?? [];

      if (cached.isEmpty) return [];

      final pings = cached
          .map((s) {
            try {
              return jsonDecode(s) as Map<String, dynamic>;
            } catch (_) {
              return null;
            }
          })
          .where((p) => p != null)
          .cast<Map<String, dynamic>>()
          .toList();

      await prefs.remove(_cacheKey);
      debugPrint('[LocationCache] Drained ${pings.length} cached pings');

      return pings;
    } catch (e) {
      debugPrint('[LocationCache] Drain error: $e');
      return [];
    }
  }

  static Future<int> getCacheSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getStringList(_cacheKey) ?? [];
      return cached.length;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
    } catch (_) {}
  }
}
