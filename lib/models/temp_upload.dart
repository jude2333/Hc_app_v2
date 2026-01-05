import 'dart:convert';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';

/// Model for offline photo uploads stored in temp_uploads table
class TempUpload {
  final String id;
  final String workOrderId;
  final String fileName;
  final String fileLocation;
  final String? fileData; // base64 encoded
  final int? fileSize;
  final String status; // pending, uploading, completed, failed
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? uploadedAt;
  final int? tenantId;
  final int? createdBy;

  TempUpload({
    required this.id,
    required this.workOrderId,
    required this.fileName,
    required this.fileLocation,
    this.fileData,
    this.fileSize,
    this.status = 'pending',
    this.errorMessage,
    required this.createdAt,
    this.uploadedAt,
    this.tenantId,
    this.createdBy,
  });

  /// Create a new TempUpload for saving offline
  factory TempUpload.create({
    required String workOrderId,
    required String fileName,
    required String fileLocation,
    required Uint8List fileBytes,
    int? tenantId,
    int? createdBy,
  }) {
    return TempUpload(
      id: const Uuid().v4(),
      workOrderId: workOrderId,
      fileName: fileName,
      fileLocation: fileLocation,
      fileData: base64Encode(fileBytes),
      fileSize: fileBytes.length,
      status: 'pending',
      createdAt: DateTime.now(),
      tenantId: tenantId,
      createdBy: createdBy,
    );
  }

  /// Parse from PowerSync/SQLite row
  factory TempUpload.fromRow(Map<String, dynamic> row) {
    return TempUpload(
      id: row['id'] as String,
      workOrderId: row['work_order_id'] as String? ?? '',
      fileName: row['file_name'] as String? ?? '',
      fileLocation: row['file_location'] as String? ?? '',
      fileData: row['file_data'] as String?,
      fileSize: row['file_size'] as int?,
      status: row['status'] as String? ?? 'pending',
      errorMessage: row['error_message'] as String?,
      createdAt: row['created_at'] != null
          ? DateTime.tryParse(row['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      uploadedAt: row['uploaded_at'] != null
          ? DateTime.tryParse(row['uploaded_at'] as String)
          : null,
      tenantId: row['tenant_id'] as int?,
      createdBy: row['created_by'] as int?,
    );
  }

  /// Convert to map for database insertion
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'work_order_id': workOrderId,
      'file_name': fileName,
      'file_location': fileLocation,
      'file_data': fileData,
      'file_size': fileSize,
      'status': status,
      'error_message': errorMessage,
      'created_at': createdAt.toIso8601String(),
      'uploaded_at': uploadedAt?.toIso8601String(),
      'tenant_id': tenantId,
      'created_by': createdBy,
    };
  }

  /// Create a copy with updated fields
  TempUpload copyWith({
    String? status,
    String? errorMessage,
    DateTime? uploadedAt,
  }) {
    return TempUpload(
      id: id,
      workOrderId: workOrderId,
      fileName: fileName,
      fileLocation: fileLocation,
      fileData: fileData,
      fileSize: fileSize,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      tenantId: tenantId,
      createdBy: createdBy,
    );
  }

  @override
  String toString() {
    return 'TempUpload(id: $id, fileName: $fileName, status: $status)';
  }
}
