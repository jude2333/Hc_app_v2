import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:anderson_crm_flutter/config/settings.dart';
import 'package:anderson_crm_flutter/repositories/storage_repository.dart';
import 'package:anderson_crm_flutter/features/session/storage_provider.dart';

import 'file_saver.dart';

class FileService {
  final Dio _dio;
  final StorageRepository _storage;

  FileService({required Dio dio, required StorageRepository storage})
      : _dio = dio,
        _storage = storage;

  static (String bucket, String key) parseS3Path(String path) {
    if (path.contains(' | ')) {
      final parts = path.split(' | ');
      return (parts[0], parts[1]);
    }
    return ('homecollection', path);
  }

  static String getExtension(String path) {
    final name = getFileName(path);
    final dotIndex = name.lastIndexOf('.');
    return dotIndex > 0 ? name.substring(dotIndex).toLowerCase() : '';
  }

  static String getFileName(String path) {
    String name = path;
    if (name.contains(' | ')) {
      name = name.split(' | ').last;
    }
    if (name.contains('/')) {
      name = name.substring(name.lastIndexOf('/') + 1);
    }
    return name;
  }

  static bool isPdf(String path) => getExtension(path) == '.pdf';

  static bool isImage(String path) {
    final ext = getExtension(path);
    return ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'].contains(ext);
  }

  /// Get a user-friendly content type label for a file
  static String getContentType(String path) {
    if (isPdf(path)) return 'PDF';
    if (isImage(path)) return 'Image';
    return 'File';
  }

  Future<Uint8List?> downloadBytes(String s3Path,
      {void Function(int, int)? onProgress}) async {
    try {
      final (bucket, key) = parseS3Path(s3Path);
      final token = await _storage.getSessionItem('pg_admin');

      final response = await _dio.post<List<int>>(
        '${Settings.nodeUrl}/s3/get_file_v2',
        data: {
          'bucket_name': bucket,
          'key': key,
          'jwt_token': token,
        },
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 30),
        ),
        onReceiveProgress: onProgress,
      );

      if (response.statusCode == 200 && response.data != null) {
        return Uint8List.fromList(response.data!);
      }
    } catch (e) {
      debugPrint('FileService download error: $e');
    }
    return null;
  }

  Future<void> downloadAndOpen(BuildContext context, String s3Path,
      {String? saveAsFileName}) async {
    final messenger = ScaffoldMessenger.of(context);
    final fileName = saveAsFileName ?? getFileName(s3Path);

    messenger.showSnackBar(
      SnackBar(
          content: Text('Downloading $fileName...'),
          duration: const Duration(seconds: 2)),
    );

    try {
      final bytes = await downloadBytes(s3Path);

      if (bytes != null && bytes.isNotEmpty) {
        await FileSaver.saveAndLaunch(bytes, fileName);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(content: Text('Opened: $fileName')),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(
              content: Text('Download failed or file empty'),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      debugPrint('downloadAndOpen error: $e');
      messenger.showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// Download file bytes and trigger a browser download (web) or save + open (mobile)
  static Future<void> saveOrOpenFile(
    BuildContext context, {
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      await FileSaver.saveAndLaunch(bytes, fileName);
      messenger.showSnackBar(
        SnackBar(content: Text('Opened: $fileName')),
      );
    } catch (e) {
      debugPrint('FileService saveOrOpen error: $e');
      messenger.showSnackBar(
        SnackBar(
            content: Text('Failed to save file: $e'),
            backgroundColor: Colors.red),
      );
    }
  }
}

final fileServiceProvider = Provider<FileService>((ref) {
  final dio = Dio();
  final storage = ref.watch(storageRepositoryProvider);
  return FileService(dio: dio, storage: storage);
});
