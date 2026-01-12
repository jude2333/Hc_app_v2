import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import 'package:anderson_crm_flutter/config/settings.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import 'package:anderson_crm_flutter/features/core/util.dart';

/// Centralized S3 file service for uploads and downloads
class S3FileService {
  final Ref _ref;
  final Dio _dio = Dio();

  S3FileService(this._ref);

  String get _jwtToken {
    final storage = _ref.read(storageServiceProvider);
    return storage.getFromSession('pg_admin');
  }

  /// Upload a file to S3
  /// Returns the file location path on success, or throws on error
  Future<String> uploadFile({
    required Uint8List bytes,
    required String fileName,
    required String folderPath,
    String bucketName = 'homecollection',
  }) async {
    try {
      final fileLocation = '$folderPath/$fileName';

      final filePart = MultipartFile.fromBytes(bytes, filename: fileName);
      FormData formData = FormData.fromMap({
        'upload_file': filePart,
        'key': fileLocation,
        'bucket_name': bucketName,
        'jwt_token': _jwtToken,
      });

      Response response = await _dio.post(
        '${Settings.nodeUrl}/s3/upload_file_v3',
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
          validateStatus: (status) => status! < 600,
        ),
      );

      if (response.statusCode == 200 && response.data == 'OK') {
        debugPrint('✅ S3 Upload success: $fileLocation');
        return fileLocation;
      } else {
        throw Exception('Upload failed: ${response.data}');
      }
    } catch (e) {
      debugPrint('❌ S3 Upload error: $e');
      rethrow;
    }
  }

  /// Upload a file from XFile (image picker result)
  Future<String> uploadXFile({
    required XFile file,
    required String folderPath,
    Uint8List? webBytes,
    String bucketName = 'homecollection',
  }) async {
    final bytes = webBytes ?? await file.readAsBytes();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';

    return uploadFile(
      bytes: bytes,
      fileName: fileName,
      folderPath: folderPath,
      bucketName: bucketName,
    );
  }

  /// Upload lab sample photo
  Future<String> uploadLabSamplePhoto({
    required XFile file,
    Uint8List? webBytes,
  }) async {
    final folderPath =
        'homecollection/lab_sample_pics/${Util.getTodayStringForFolderCreation()}';
    return uploadXFile(
      file: file,
      folderPath: folderPath,
      webBytes: webBytes,
    );
  }

  /// Download a file from S3
  /// Returns the file bytes on success
  Future<Uint8List> downloadFile({
    required String filePath,
    String bucketName = 'homecollection',
  }) async {
    try {
      // Parse bucket and key from path if format is "bucket/key"
      String bucket = bucketName;
      String key = filePath;

      if (filePath.contains(' | ')) {
        final parts = filePath.split(' | ');
        bucket = parts[0];
        key = parts[1];
      } else if (filePath.startsWith('homecollection/')) {
        bucket = 'homecollection';
        key = filePath;
      }

      final data = {
        'bucket_name': bucket,
        'key': key,
        'jwt_token': _jwtToken,
      };

      Response<List<int>> response = await _dio.post(
        '${Settings.nodeUrl}/s3/get_file_v2',
        data: data,
        options: Options(
          responseType: ResponseType.bytes,
          validateStatus: (status) => status! < 600,
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        debugPrint('✅ S3 Download success: $key');
        return Uint8List.fromList(response.data!);
      } else {
        throw Exception('Download failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ S3 Download error: $e');
      rethrow;
    }
  }

  /// Get a signed URL for viewing a file (useful for images/PDFs)
  String getViewUrl(String filePath) {
    // For viewing, we can construct a direct URL or use an API endpoint
    // In this case, return the path for now - actual implementation may vary
    return filePath;
  }

  /// Extract filename from a path
  static String getFileName(String path) {
    if (path.contains('/')) {
      return path.substring(path.lastIndexOf('/') + 1);
    }
    return path;
  }
}

final s3FileServiceProvider = Provider<S3FileService>((ref) {
  return S3FileService(ref);
});
