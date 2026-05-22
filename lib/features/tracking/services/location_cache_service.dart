import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Caches location pings locally when WebSocket is disconnected.
/// On reconnect, the provider reads this cache and bulk-POSTs to the server.
///
/// Uses SharedPreferences for simplicity (JSON-encoded list of pings).
/// For very high volume, consider sqflite instead.
class LocationCacheService {
  static const String _cacheKey = 'tracking_cached_pings';
  static const int _maxCacheSize = 500; // Max pings to cache

  /// Add a ping to the local cache
  static Future<void> cachePing(Map<String, dynamic> ping) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getStringList(_cacheKey) ?? [];

      cached.add(jsonEncode(ping));

      // Trim if too large (keep most recent)
      if (cached.length > _maxCacheSize) {
        cached.removeRange(0, cached.length - _maxCacheSize);
      }

      await prefs.setStringList(_cacheKey, cached);
      debugPrint('[LocationCache] Cached ping (${cached.length} total)');
    } catch (e) {
      debugPrint('[LocationCache] Cache error: $e');
    }
  }

  /// Add multiple pings to the local cache in a single transaction
  static Future<void> cachePings(List<Map<String, dynamic>> pings) async {
    if (pings.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getStringList(_cacheKey) ?? [];

      for (final ping in pings) {
        cached.add(jsonEncode(ping));
      }

      // Trim if too large (keep most recent)
      if (cached.length > _maxCacheSize) {
        cached.removeRange(0, cached.length - _maxCacheSize);
      }

      await prefs.setStringList(_cacheKey, cached);
      debugPrint('[LocationCache] Cached ${pings.length} pings in batch (${cached.length} total)');
    } catch (e) {
      debugPrint('[LocationCache] Batch cache error: $e');
    }
  }

  /// Get all cached pings WITHOUT clearing the cache.
  /// Used for safe sync: read first, clear only after successful upload.
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

  /// Get all cached pings and clear the cache
  static Future<List<Map<String, dynamic>>> drainCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getStringList(_cacheKey) ?? [];

      if (cached.isEmpty) return [];

      // Parse all cached pings
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

      // Clear the cache
      await prefs.remove(_cacheKey);
      debugPrint('[LocationCache] Drained ${pings.length} cached pings');

      return pings;
    } catch (e) {
      debugPrint('[LocationCache] Drain error: $e');
      return [];
    }
  }

  /// Get the number of cached pings
  static Future<int> getCacheSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getStringList(_cacheKey) ?? [];
      return cached.length;
    } catch (_) {
      return 0;
    }
  }

  /// Clear all cached pings
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
    } catch (_) {}
  }
}
