import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:powersync/powersync.dart';
import '../models/temp_upload.dart';
import '../powersync/powersync_service.dart';

class TempUploadRepository {
  final PowerSyncDatabase db;

  TempUploadRepository(this.db);

  Future<TempUpload> saveOfflinePhoto({
    required String workOrderId,
    required String fileName,
    required String fileLocation,
    required Uint8List fileBytes,
    int? tenantId,
    int? createdBy,
  }) async {
    final upload = TempUpload.create(
      workOrderId: workOrderId,
      fileName: fileName,
      fileLocation: fileLocation,
      fileBytes: fileBytes,
      tenantId: tenantId,
      createdBy: createdBy,
    );

    debugPrint(
        '📷 Saving offline photo: ${upload.fileName} (${upload.fileSize} bytes)');

    await db.execute('''
      INSERT INTO temp_uploads (
        id, work_order_id, file_name, file_location, 
        file_data, file_size, status, created_at, tenant_id, created_by
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      upload.id,
      upload.workOrderId,
      upload.fileName,
      upload.fileLocation,
      upload.fileData,
      upload.fileSize,
      upload.status,
      upload.createdAt.toIso8601String(),
      upload.tenantId,
      upload.createdBy,
    ]);

    debugPrint('✅ Photo saved offline: ${upload.id}');
    return upload;
  }

  Future<List<TempUpload>> getPendingUploads() async {
    final results = await db.getAll('''
      SELECT * FROM temp_uploads 
      WHERE status = 'pending'
      ORDER BY created_at ASC
    ''');
    return results.map((row) => TempUpload.fromRow(row)).toList();
  }

  Future<List<TempUpload>> getUploadsForWorkOrder(String workOrderId) async {
    final results = await db.getAll('''
      SELECT * FROM temp_uploads 
      WHERE work_order_id = ?
      ORDER BY created_at ASC
    ''', [workOrderId]);
    return results.map((row) => TempUpload.fromRow(row)).toList();
  }

  Stream<int> watchPendingCount() {
    return db.watch(
        'SELECT COUNT(*) as count FROM temp_uploads WHERE status = ?',
        parameters: ['pending']).handleError((e) {
      debugPrint('[TempUpload] watch stream error (ignored): $e');
    }).map((results) {
      if (results.isEmpty) return 0;
      return results.first['count'] as int? ?? 0;
    });
  }

  Stream<List<TempUpload>> watchUploadsForWorkOrder(String workOrderId) {
    return db.watch(
      'SELECT * FROM temp_uploads WHERE work_order_id = ? ORDER BY created_at ASC',
      parameters: [workOrderId],
    ).handleError((e) {
      debugPrint('[TempUpload] watch stream error (ignored): $e');
    }).map((results) => results.map((row) => TempUpload.fromRow(row)).toList());
  }

  Future<void> updateStatus(String id, String status,
      {String? errorMessage}) async {
    if (status == 'completed') {
      await db.execute('''
        UPDATE temp_uploads 
        SET status = ?, uploaded_at = ?, error_message = ?
        WHERE id = ?
      ''', [status, DateTime.now().toIso8601String(), errorMessage, id]);
    } else {
      await db.execute('''
        UPDATE temp_uploads 
        SET status = ?, error_message = ?
        WHERE id = ?
      ''', [status, errorMessage, id]);
    }
  }

  Future<void> delete(String id) async {
    await db.execute('DELETE FROM temp_uploads WHERE id = ?', [id]);
  }

  Future<int> cleanupOldUploads({int olderThanDays = 1}) async {
    final cutoffDate = DateTime.now()
        .subtract(Duration(days: olderThanDays))
        .toIso8601String();

    final countResult = await db.getAll('''
      SELECT COUNT(*) as count FROM temp_uploads 
      WHERE status = 'completed' AND uploaded_at < ?
    ''', [cutoffDate]);
    final count =
        countResult.isNotEmpty ? (countResult.first['count'] as int? ?? 0) : 0;

    await db.execute('''
      DELETE FROM temp_uploads 
      WHERE status = 'completed' AND uploaded_at < ?
    ''', [cutoffDate]);

    return count;
  }
}

final tempUploadRepositoryProvider = Provider<TempUploadRepository>((ref) {
  final powerSync = ref.watch(powerSyncServiceProvider);
  return TempUploadRepository(powerSync.db);
});
