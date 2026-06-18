import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import 'package:anderson_crm_flutter/config/settings.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import 'package:anderson_crm_flutter/features/core/util.dart';

class S3FileService {
  final Ref _ref;
  final Dio _dio = Dio();

  /// HTTP timeout for S3 file downloads
  static const _downloadTimeout = Duration(seconds: 30);

  /// Number of retry attempts for transient failures
  static const _maxRetries = 2;

  /// Base delay between retries (doubles each attempt: 2s, 4s)
  static const _baseRetryDelay = Duration(seconds: 2);

  S3FileService(this._ref);

  String get _jwtToken {
    final storage = _ref.read(storageServiceProvider);
    return storage.getFromSession('pg_admin');
  }

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
        debugPrint(' S3 Upload success: $fileLocation');
        return fileLocation;
      } else {
        throw Exception('Upload failed: ${response.data}');
      }
    } catch (e) {
      debugPrint(' S3 Upload error: $e');
      rethrow;
    }
  }

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

  /// Download a file from S3 with retry logic and content validation.
  ///
  /// Retries up to [_maxRetries] times on transient failures (network errors,
  /// server 500s). Returns validated bytes on success.
  ///
  /// Throws [S3DownloadException] with a user-friendly message on failure.
  Future<Uint8List> downloadFile({
    required String filePath,
    String bucketName = 'homecollection',
  }) async {
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

    Exception? lastError;

    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      if (attempt > 0) {
        final delay = _baseRetryDelay * (1 << (attempt - 1));
        debugPrint('[S3] Retry attempt $attempt/$_maxRetries for: $key (delay: ${delay.inSeconds}s)');
        await Future.delayed(delay);
      }

      try {
        final response = await _dio.post<List<int>>(
          '${Settings.nodeUrl}/s3/get_file_v2',
          data: data,
          options: Options(
            responseType: ResponseType.bytes,
            sendTimeout: _downloadTimeout,
            receiveTimeout: _downloadTimeout,
            validateStatus: (status) => status! < 600,
          ),
        );

        // Handle HTTP error status codes (server now returns proper codes)
        if (response.statusCode == 401) {
          throw S3DownloadException(
            'Session expired. Please log in again.',
            isAuthError: true,
          );
        }

        if (response.statusCode == 404) {
          throw S3DownloadException(
            'File not found in storage.',
            isNotFound: true,
          );
        }

        if (response.statusCode != null && response.statusCode! >= 500) {
          throw S3DownloadException(
            'Server error (${response.statusCode}). Please try again.',
            isRetryable: true,
          );
        }

        if (response.statusCode != 200 || response.data == null) {
          throw S3DownloadException(
            'Download failed (HTTP ${response.statusCode}).',
            isRetryable: true,
          );
        }

        final bytes = Uint8List.fromList(response.data!);

        // Validate that we didn't receive an error message as bytes
        // (backward compatibility with servers that may still return 200 + error text)
        if (_isErrorResponse(bytes)) {
          final errorText = String.fromCharCodes(bytes);
          debugPrint('[S3] Received error text as bytes: $errorText');
          throw S3DownloadException(
            'File not available in storage.',
            isNotFound: true,
          );
        }

        // Validate minimum content size
        if (bytes.isEmpty) {
          throw S3DownloadException(
            'Downloaded file is empty.',
            isNotFound: true,
          );
        }

        debugPrint('[S3] Download success: $key (${bytes.length} bytes)');
        return bytes;
      } on S3DownloadException catch (e) {
        // Don't retry auth or not-found errors
        if (!e.isRetryable) rethrow;
        lastError = e;
      } on DioException catch (e) {
        debugPrint('[S3] DioException on attempt $attempt: ${e.type}');
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.sendTimeout) {
          lastError = S3DownloadException(
            'Connection timed out. Check your network.',
            isRetryable: true,
          );
        } else if (e.type == DioExceptionType.connectionError) {
          lastError = S3DownloadException(
            'Cannot reach server. Check your network.',
            isRetryable: true,
          );
        } else {
          lastError = S3DownloadException(
            'Network error: ${e.message}',
            isRetryable: true,
          );
        }
      } catch (e) {
        debugPrint('[S3] Unexpected error on attempt $attempt: $e');
        lastError = S3DownloadException('Unexpected error: $e');
      }
    }

    throw lastError ?? S3DownloadException('Download failed after retries.');
  }

  /// Check if the response bytes contain an error message instead of file data.
  /// Servers may return "ERROR:..." as plain text with HTTP 200.
  bool _isErrorResponse(Uint8List bytes) {
    if (bytes.length > 500) return false; // Real files are larger
    try {
      final text = String.fromCharCodes(bytes);
      return text.startsWith('ERROR') ||
          text.contains('Invalid Token') ||
          text.contains('Invalid Credentials');
    } catch (_) {
      return false;
    }
  }

  // ── Content Validation Helpers ──

  /// Check if bytes represent a valid PDF (starts with %PDF)
  static bool isValidPdf(Uint8List bytes) {
    if (bytes.length < 4) return false;
    return bytes[0] == 0x25 && // %
        bytes[1] == 0x50 && // P
        bytes[2] == 0x44 && // D
        bytes[3] == 0x46; // F
  }

  /// Check if bytes represent a valid image (JPEG, PNG, GIF, WebP, BMP)
  static bool isValidImage(Uint8List bytes) {
    if (bytes.length < 4) return false;
    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return true;
    }
    // PNG: 89 50 4E 47
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return true;
    }
    // GIF: 47 49 46 38
    if (bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38) {
      return true;
    }
    // WebP: RIFF....WEBP
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return true;
    }
    // BMP: 42 4D
    if (bytes[0] == 0x42 && bytes[1] == 0x4D) return true;
    return false;
  }

  static String getFileName(String path) {
    if (path.contains('/')) {
      return path.substring(path.lastIndexOf('/') + 1);
    }
    return path;
  }
}

/// Structured exception for S3 download errors with classification.
class S3DownloadException implements Exception {
  final String message;
  final bool isAuthError;
  final bool isNotFound;
  final bool isRetryable;

  S3DownloadException(
    this.message, {
    this.isAuthError = false,
    this.isNotFound = false,
    this.isRetryable = false,
  });

  @override
  String toString() => message;
}

final s3FileServiceProvider = Provider<S3FileService>((ref) {
  return S3FileService(ref);
});
