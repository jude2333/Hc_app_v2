import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:anderson_crm_flutter/config/settings.dart';

class AppUpdateService {
  static Future<UpdateInfo?> checkForUpdate() async {
    if (kIsWeb) return null;

    try {
      final dio = Dio();
      final response = await dio.get(
        '${Settings.nodeUrl}/app/version.json',
        options: Options(
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
      debugPrint('[AppUpdate] Check failed (non-fatal): $e');
      return null;
    }
  }

  static bool _isNewer(String newer, String current) {
    if (newer.isEmpty || current.isEmpty) return false;

    final newParts = newer.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final curParts =
        current.split('.').map((e) => int.tryParse(e) ?? 0).toList();

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
    return false;
  }

  /// Returns APK download info from server for web dashboard display.
  /// No version comparison — just fetches the latest available APK details.
  static Future<ApkDownloadInfo?> getApkDownloadInfo() async {
    try {
      final dio = Dio();
      final response = await dio.get(
        '${Settings.nodeUrl}/app/version.json',
        options: Options(
          headers: {'Cache-Control': 'no-cache'},
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        ),
      );

      if (response.statusCode != 200 || response.data == null) return null;

      final data = response.data as Map<String, dynamic>;
      final apkUrl = data['apk_url'] as String? ?? '';
      final version = data['version'] as String? ?? '';

      if (apkUrl.isEmpty || version.isEmpty) return null;

      return ApkDownloadInfo(
        version: version,
        apkUrl: apkUrl,
        releaseNotes: data['release_notes'] as String? ?? '',
      );
    } catch (e) {
      debugPrint('[AppUpdate] Download info fetch failed: $e');
      return null;
    }
  }
}

class UpdateInfo {
  final String currentVersion;
  final String newVersion;
  final String minVersion;
  final String apkUrl;
  final String releaseNotes;
  final int buildNumber;
  final bool isForced;

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

class ApkDownloadInfo {
  final String version;
  final String apkUrl;
  final String releaseNotes;

  const ApkDownloadInfo({
    required this.version,
    required this.apkUrl,
    required this.releaseNotes,
  });
}
