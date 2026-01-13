import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:anderson_crm_flutter/config/settings.dart';
import 'package:anderson_crm_flutter/repositories/storage_repository.dart';

/// Service for downloading and managing files from S3
class FileService {
  final Dio _dio;
  final StorageRepository _storage;

  FileService({required Dio dio, required StorageRepository storage})
      : _dio = dio,
        _storage = storage;

  /// Parse S3 path into bucket and key
  static (String bucket, String key) parseS3Path(String path) {
    if (path.contains(' | ')) {
      final parts = path.split(' | ');
      return (parts[0], parts[1]);
    }
    return ('homecollection', path);
  }

  /// Get file extension from path
  static String getExtension(String path) {
    final name = getFileName(path);
    final dotIndex = name.lastIndexOf('.');
    return dotIndex > 0 ? name.substring(dotIndex).toLowerCase() : '';
  }

  /// Get file name from path
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

  /// Check if file is PDF
  static bool isPdf(String path) => getExtension(path) == '.pdf';

  /// Check if file is image
  static bool isImage(String path) {
    final ext = getExtension(path);
    return ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'].contains(ext);
  }

  /// Download file bytes from S3
  Future<Uint8List?> downloadBytes(String s3Path,
      {void Function(int, int)? onProgress}) async {
    try {
      final (bucket, key) = parseS3Path(s3Path);
      final token = _storage.getSessionItem('pg_admin');

      final response = await _dio.post<List<int>>(
        '${Settings.nodeUrl}/s3/get_file_v2',
        data: {
          'bucket_name': bucket,
          'key': key,
          'jwt_token': token,
        },
        options: Options(responseType: ResponseType.bytes),
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

  /// Download and save file to device
  Future<String?> downloadToDevice(String s3Path,
      {void Function(int, int)? onProgress}) async {
    try {
      final bytes = await downloadBytes(s3Path, onProgress: onProgress);
      if (bytes == null) return null;

      final fileName = getFileName(s3Path);
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      return filePath;
    } catch (e) {
      debugPrint('FileService save error: $e');
    }
    return null;
  }

  /// Download and open file
  Future<void> downloadAndOpen(BuildContext context, String s3Path) async {
    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(
      const SnackBar(
          content: Text('Downloading...'), duration: Duration(seconds: 10)),
    );

    final filePath = await downloadToDevice(s3Path);

    messenger.hideCurrentSnackBar();

    if (filePath != null) {
      await OpenFilex.open(filePath);
    } else {
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Download failed'), backgroundColor: Colors.red),
      );
    }
  }
}
