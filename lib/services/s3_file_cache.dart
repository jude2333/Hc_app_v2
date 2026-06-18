import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:anderson_crm_flutter/services/s3_file_service.dart';

/// In-memory LRU cache for S3 file downloads.
///
/// Prevents redundant network calls when re-viewing the same file.
/// Evicts least-recently-used entries when total size exceeds [_maxCacheBytes].
class S3FileCache {
  final S3FileService _s3Service;

  /// 50 MB max cache
  static const int _maxCacheBytes = 50 * 1024 * 1024;

  /// Cached entries keyed by S3 path.
  final Map<String, _CacheEntry> _cache = {};

  /// In-flight downloads to coalesce concurrent requests for the same key.
  final Map<String, Future<Uint8List>> _pending = {};

  int _totalBytes = 0;

  S3FileCache(this._s3Service);

  /// Returns cached bytes or downloads from S3 and caches the result.
  ///
  /// Concurrent calls for the same [s3Path] share a single download future.
  Future<Uint8List> getFile(String s3Path, {String bucketName = 'homecollection'}) async {
    // Cache hit — move to end (most-recently-used)
    final existing = _cache.remove(s3Path);
    if (existing != null) {
      _cache[s3Path] = existing;
      debugPrint('[S3Cache] Hit: $s3Path (${existing.bytes.length} bytes)');
      return existing.bytes;
    }

    // Coalesce concurrent requests
    if (_pending.containsKey(s3Path)) {
      debugPrint('[S3Cache] Coalescing request: $s3Path');
      return _pending[s3Path]!;
    }

    final future = _download(s3Path, bucketName);
    _pending[s3Path] = future;

    try {
      return await future;
    } finally {
      _pending.remove(s3Path);
    }
  }

  Future<Uint8List> _download(String s3Path, String bucketName) async {
    final bytes = await _s3Service.downloadFile(
      filePath: s3Path,
      bucketName: bucketName,
    );

    _put(s3Path, bytes);
    return bytes;
  }

  void _put(String key, Uint8List bytes) {
    // Don't cache files larger than half the max (avoid single-file eviction storms)
    if (bytes.length > _maxCacheBytes ~/ 2) {
      debugPrint('[S3Cache] Skipping cache for oversized file: ${bytes.length} bytes');
      return;
    }

    // Evict LRU entries until we have room
    while (_totalBytes + bytes.length > _maxCacheBytes && _cache.isNotEmpty) {
      final oldestKey = _cache.keys.first;
      final evicted = _cache.remove(oldestKey)!;
      _totalBytes -= evicted.bytes.length;
      debugPrint('[S3Cache] Evicted: $oldestKey (${evicted.bytes.length} bytes)');
    }

    _cache[key] = _CacheEntry(bytes);
    _totalBytes += bytes.length;
    debugPrint('[S3Cache] Cached: $key (${bytes.length} bytes, total: $_totalBytes)');
  }

  /// Remove a specific entry (e.g. after a failed validation).
  void invalidate(String s3Path) {
    final removed = _cache.remove(s3Path);
    if (removed != null) {
      _totalBytes -= removed.bytes.length;
    }
  }

  /// Clear entire cache.
  void clear() {
    _cache.clear();
    _totalBytes = 0;
    debugPrint('[S3Cache] Cleared');
  }
}

class _CacheEntry {
  final Uint8List bytes;
  _CacheEntry(this.bytes);
}

final s3FileCacheProvider = Provider<S3FileCache>((ref) {
  final s3Service = ref.watch(s3FileServiceProvider);
  return S3FileCache(s3Service);
});
