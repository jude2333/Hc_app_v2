import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:anderson_crm_flutter/config/settings.dart';

/// Checks if a newer APK version is available on the server.
/// Only runs on Android — skipped on web.
class AppUpdateService {
  /// Check for updates by fetching /app/version.json from the server.
  /// Returns [UpdateInfo] if update is available, null if up-to-date.
  static Future<UpdateInfo?> checkForUpdate() async {
    // Skip on web — web always gets latest on refresh
    if (kIsWeb) return null;

    try {
      final dio = Dio();
      final response = await dio.get(
        '${Settings.nodeUrl}/app/version.json',
        options: Options(
          // Bypass any HTTP cache
          headers: {'Cache-Control': 'no-cache'},
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        ),
      );

      if (response.statusCode != 200 || response.data == null) return null;

      final data = response.data as Map<String, dynamic>;
      final serverVersion = data['version'] as String? ?? '';
      final minVersion = data['min_version'] as String? ?? '';
      final apkUrl = data['apk_url'] as String? ?? '';
      final releaseNotes = data['release_notes'] as String? ?? '';
      final buildNumber = data['build_number'] as int? ?? 0;

      if (serverVersion.isEmpty || apkUrl.isEmpty) return null;

      final currentVersion = Settings.version;

      // Compare versions
      final hasUpdate = _isNewer(serverVersion, currentVersion);
      final isForced = _isNewer(minVersion, currentVersion);

      if (!hasUpdate) return null;

      return UpdateInfo(
        currentVersion: currentVersion,
        newVersion: serverVersion,
        minVersion: minVersion,
        apkUrl: apkUrl,
        releaseNotes: releaseNotes,
        buildNumber: buildNumber,
        isForced: isForced,
      );
    } catch (e) {
      // Update check failure is non-fatal — user can still use the app
      debugPrint('[AppUpdate] Check failed (non-fatal): $e');
      return null;
    }
  }

  /// Compare two semver strings (e.g., "2.8.5" > "2.8.4")
  /// Returns true if [newer] is greater than [current]
  static bool _isNewer(String newer, String current) {
    if (newer.isEmpty || current.isEmpty) return false;

    final newParts = newer.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final curParts =
        current.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    // Pad to same length
    while (newParts.length < 3) {
      newParts.add(0);
    }
    while (curParts.length < 3) {
      curParts.add(0);
    }

    for (int i = 0; i < 3; i++) {
      if (newParts[i] > curParts[i]) return true;
      if (newParts[i] < curParts[i]) return false;
    }
    return false; // Equal
  }
}

/// Data class for update information
class UpdateInfo {
  final String currentVersion;
  final String newVersion;
  final String minVersion;
  final String apkUrl;
  final String releaseNotes;
  final int buildNumber;
  final bool isForced; // true = user CANNOT skip this update

  const UpdateInfo({
    required this.currentVersion,
    required this.newVersion,
    required this.minVersion,
    required this.apkUrl,
    required this.releaseNotes,
    required this.buildNumber,
    required this.isForced,
  });
}
