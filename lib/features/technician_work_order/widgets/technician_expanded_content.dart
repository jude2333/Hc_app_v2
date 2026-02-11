import 'dart:io';
import 'dart:typed_data';
import 'dart:html' as html;
import 'dart:ui_web' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import 'package:anderson_crm_flutter/services/s3_file_service.dart';
import 'package:anderson_crm_flutter/features/core/widgets/file_viewer/file_viewer_exports.dart';
import '../../theme/theme.dart';
import '../providers/technician_work_order_provider.dart';

class TechnicianExpandedContent extends ConsumerStatefulWidget {
  final WorkOrder workOrder;

  const TechnicianExpandedContent({super.key, required this.workOrder});

  @override
  ConsumerState<TechnicianExpandedContent> createState() =>
      _TechnicianExpandedContentState();
}

class _TechnicianExpandedContentState
    extends ConsumerState<TechnicianExpandedContent> {
  late bool _remittance;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _remittance = widget.workOrder.parsedDoc['remittance'] == true;
  }

  @override
  Widget build(BuildContext context) {
    final wo = widget.workOrder;
    final isCancelled = wo.status == 'cancelled' || wo.status == 'NA';
    final isFinished = wo.status == 'Finished';
    final acceptRemittance = wo.parsedDoc['accept_remittance'] == true;
    final labSampleAccepted = wo.parsedDoc['lab_sample_pics_accepted'] == true;
    final gpayRef = wo.parsedDoc['gpay_ref']?.toString() ?? '';
    final remarks = wo.parsedDoc['remarks']?.toString() ?? '';
    final testItems = wo.parsedDoc['test_items'];
    final labSamplePics = wo.parsedDoc['lab_sample_pics']?.toString() ?? '';
    final reportStatus = wo.parsedDoc['report_status']?.toString() ?? '';
    final reportPath = wo.parsedDoc['report_path']?.toString() ?? '';
    final proformaPath = wo.parsedDoc['second_step']?.toString() ?? '';
    final prescriptionPath = wo.prescriptionPath;

    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        border: Border(
          left: BorderSide(color: AppColors.primary, width: 3),
          top: BorderSide(color: AppColors.divider),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isCancelled) ...[
            // Test Items
            _buildActionRow('Test Items', testItems != null ? 'View' : 'Nil',
                showAction: testItems != null,
                onAction:
                    testItems != null ? () => _viewTests(testItems) : null),

            // GPay
            if (isFinished && gpayRef == 'Later')
              _buildActionRow('GPay', 'Edit',
                  showAction: true, onAction: _editGPay)
            else
              _buildInfoRow('GPay', gpayRef.isEmpty ? 'Nil' : gpayRef),

            // Prescription Photo - NEW: with view/download
            _buildFileRow(
              'Prescription',
              prescriptionPath,
              showUpload: false,
            ),

            // Proforma - with view/download
            _buildFileRow(
              'Proforma',
              proformaPath,
              showUpload: false,
            ),

            // Remittance Toggle
            if (isFinished && !acceptRemittance)
              _buildRemittanceRow()
            else if (acceptRemittance)
              _buildInfoRow('Remittance', 'Accepted ✓',
                  valueColor: AppColors.success),

            // Lab Samples - with upload/view/download
            if (labSampleAccepted)
              _buildInfoRow('Lab Samples', 'Accepted ✓',
                  valueColor: AppColors.success)
            else
              _buildLabSamplesRow(labSamplePics),

            // Remarks
            _buildActionRow('Remarks', remarks.isEmpty ? 'Add' : 'Edit',
                showAction: true, onAction: () => _editRemarks(remarks)),

            // Report Status
            if (reportStatus.isNotEmpty)
              _buildReportStatusRow(wo, reportStatus),

            // Report PDF - with view/download
            _buildFileRow(
              'Report PDF',
              reportPath,
              showUpload: false,
              icon: Icons.picture_as_pdf,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 120,
              child: Text(label,
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 13,
                    color: valueColor ?? AppColors.textPrimary,
                    fontWeight: valueColor != null ? FontWeight.w500 : null)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(String label, String buttonText,
      {bool showAction = false, VoidCallback? onAction, IconData? icon}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(
              width: 120,
              child: Text(label,
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          if (showAction && onAction != null)
            InkWell(
              onTap: onAction,
              borderRadius: AppRadius.smAll,
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: AppRadius.smAll,
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 14, color: AppColors.primary),
                      SizedBox(width: AppSpacing.xs)
                    ],
                    Text(buttonText,
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            )
          else
            Text(buttonText,
                style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  /// Generic file row with view/download capability
  Widget _buildFileRow(String label, String path,
      {bool showUpload = false, IconData? icon}) {
    final hasFile = path.isNotEmpty;
    final fileName = hasFile ? _getFileName(path) : 'Nil';
    final fileCount = hasFile && path.contains(',')
        ? '${path.split(',').length} files'
        : fileName;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(
              width: 120,
              child: Text(label,
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          if (hasFile)
            InkWell(
              onTap: () => _viewFile(path),
              borderRadius: AppRadius.smAll,
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.1),
                  borderRadius: AppRadius.smAll,
                  border: Border.all(color: AppColors.secondary),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon ?? Icons.open_in_new,
                        size: 12, color: AppColors.secondary),
                    SizedBox(width: AppSpacing.xs),
                    Text(fileCount,
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            )
          else
            Text('Nil',
                style: TextStyle(fontSize: 13, color: AppColors.textHint)),
        ],
      ),
    );
  }

  Widget _buildRemittanceRow() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(
              width: 120,
              child: Text(_remittance ? 'Remitted' : 'Remittance',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          Transform.scale(
            scale: 0.8,
            child: Switch(
                value: _remittance,
                activeColor: AppColors.success,
                onChanged: _toggleRemittance),
          ),
        ],
      ),
    );
  }

  Widget _buildLabSamplesRow(String existingPics) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(
              width: 120,
              child: Text('Lab Samples',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          if (_isUploading)
            SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
          else
            IconButton(
                icon: Icon(Icons.cloud_upload,
                    color: AppColors.primary, size: 20),
                onPressed: _uploadLabSample,
                visualDensity: VisualDensity.compact,
                tooltip: 'Upload'),
          if (existingPics.isNotEmpty)
            InkWell(
              onTap: () => _viewFile(existingPics),
              borderRadius: AppRadius.smAll,
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: AppRadius.smAll,
                  border: Border.all(color: AppColors.success),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.visibility, size: 12, color: AppColors.success),
                    SizedBox(width: AppSpacing.xs),
                    Text(_getFileCount(existingPics),
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.success,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getFileName(String path) =>
      path.contains('/') ? path.substring(path.lastIndexOf('/') + 1) : path;

  String _getFileCount(String path) {
    if (path.isEmpty) return '';
    final files = path.split(',').where((f) => f.trim().isNotEmpty).toList();
    return files.length > 1 ? '${files.length} files' : 'View';
  }

  Color _getReportStatusColor(String status) {
    final s = status.toLowerCase();
    if (s == 'complete' || s == 'billed') return AppColors.success;
    if (s == 'part') return AppColors.secondary;
    if (s == 'error') return AppColors.error;
    return AppColors.textSecondary;
  }

  Widget _buildReportStatusRow(WorkOrder wo, String reportStatus) {
    final statusInNumber = wo.parsedDoc['status_in_number']?.toString() ?? '';
    final displayText = statusInNumber.isNotEmpty
        ? '$statusInNumber $reportStatus'
        : reportStatus;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(
              width: 120,
              child: Text('Report Status',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              border: Border.all(color: _getReportStatusColor(reportStatus)),
              borderRadius: AppRadius.smAll,
            ),
            child: Text(
              displayText,
              style: TextStyle(
                fontSize: 12,
                color: _getReportStatusColor(reportStatus),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========================
  // FILE VIEW/DOWNLOAD LOGIC
  // ========================

  /// View file(s) - handles single or multiple files
  void _viewFile(String path) {
    if (path.isEmpty) return;

    final files = path.contains(',')
        ? path
            .split(',')
            .map((f) => f.trim())
            .where((f) => f.isNotEmpty)
            .toList()
        : [path];

    if (files.length == 1) {
      _openFileViewer(files.first);
    } else {
      FilePickerDialog.show(
        context,
        files: files,
        title: 'View / Download Files',
        onAction: (selectedPath, action) {
          if (action == 'view') {
            _openFileViewer(selectedPath);
          } else {
            _downloadAndSave(selectedPath);
          }
        },
      );
    }
  }

  /// Opens fullscreen viewer for image or PDF
  void _openFileViewer(String path) async {
    final messenger = ScaffoldMessenger.of(context);
    final fileName = FileService.getFileName(path);

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white)),
            const SizedBox(width: 12),
            Text('Loading $fileName...'),
          ],
        ),
        duration: const Duration(seconds: 30),
      ),
    );

    try {
      messenger.hideCurrentSnackBar();

      if (FileService.isPdf(path)) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                _TechFullScreenPdfViewer(s3Path: path, title: fileName),
          ),
        );
      } else if (FileService.isImage(path)) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                _TechFullScreenImageViewer(s3Path: path, title: fileName),
          ),
        );
      } else {
        // Unknown file type - try to download
        _downloadAndSave(path);
      }
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _downloadAndSave(String path) async {
    try {
      final s3Service = ref.read(s3FileServiceProvider);
      await s3Service.downloadFile(filePath: path);
      final fileName = _getFileName(path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Downloaded: $fileName'),
            backgroundColor: AppColors.success));
      }
    } catch (e) {
      debugPrint('Download error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: AppColors.error));
      }
    }
  }

  // ========================
  // ACTIONS
  // ========================

  Future<void> _toggleRemittance(bool value) async {
    final storage = ref.read(storageServiceProvider);
    final user = storage.getFromSession('logged_in_emp_name');
    setState(() => _remittance = value);
    final success = await ref
        .read(technicianWorkOrderProvider)
        .updateRemittance(widget.workOrder, value, user);
    if (!success && mounted) {
      setState(() => _remittance = !value);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to update remittance')));
    } else if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(value ? 'Remittance Made' : 'Remittance Cancelled'),
          backgroundColor: AppColors.success));
    }
  }

  void _viewTests(dynamic testItems) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text('Test Items'),
              content: SingleChildScrollView(child: Text(testItems.toString())),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx), child: Text('OK'))
              ],
            ));
  }

  void _editGPay() {
    final controller = TextEditingController();
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text('Edit GPay Reference'),
              content: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                      hintText: 'Enter GPay Reference',
                      border: OutlineInputBorder())),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
                ElevatedButton(
                    onPressed: () async {
                      final storage = ref.read(storageServiceProvider);
                      final user = storage.getFromSession('logged_in_emp_name');
                      final success = await ref
                          .read(technicianWorkOrderProvider)
                          .updateGPayRef(
                              widget.workOrder, controller.text, user);
                      if (mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(success
                                ? 'GPay Updated'
                                : 'Failed to update')));
                      }
                    },
                    child: Text('Save')),
              ],
            ));
  }

  void _editRemarks(String currentRemarks) {
    final controller = TextEditingController(text: currentRemarks);
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text('Edit Remarks'),
              content: TextField(
                  controller: controller,
                  maxLines: 3,
                  decoration: InputDecoration(
                      hintText: 'Enter remarks...',
                      border: OutlineInputBorder())),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
                ElevatedButton(
                    onPressed: () async {
                      final storage = ref.read(storageServiceProvider);
                      final user = storage.getFromSession('logged_in_emp_name');
                      final success = await ref
                          .read(technicianWorkOrderProvider)
                          .updateRemarks(
                              widget.workOrder, controller.text, user);
                      if (mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(success
                                ? 'Remarks Updated'
                                : 'Failed to update')));
                      }
                    },
                    child: Text('Save')),
              ],
            ));
  }

  Future<void> _uploadLabSample() async {
    final source = await showDialog<ImageSource>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text('Select Source'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                ListTile(
                    leading: Icon(Icons.camera_alt),
                    title: Text('Camera'),
                    onTap: () => Navigator.pop(ctx, ImageSource.camera)),
                ListTile(
                    leading: Icon(Icons.photo_library),
                    title: Text('Gallery'),
                    onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
              ]),
            ));
    if (source == null) return;

    try {
      final pickedFile =
          await ImagePicker().pickImage(source: source, imageQuality: 80);
      if (pickedFile == null) return;
      setState(() => _isUploading = true);

      Uint8List? webBytes;
      if (kIsWeb) webBytes = await pickedFile.readAsBytes();

      final s3Service = ref.read(s3FileServiceProvider);
      final uploadedPath = await s3Service.uploadLabSamplePhoto(
          file: pickedFile, webBytes: webBytes);

      final storage = ref.read(storageServiceProvider);
      final user = storage.getFromSession('logged_in_emp_name');
      final success = await ref
          .read(technicianWorkOrderProvider)
          .addLabSamplePhoto(widget.workOrder, uploadedPath, user);

      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(success ? 'Photo Uploaded Successfully' : 'Upload Failed'),
            backgroundColor: success ? AppColors.success : AppColors.error));
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: AppColors.error));
      }
    }
  }
}

// ======================================
// FULLSCREEN IMAGE VIEWER (Same as Manager)
// ======================================

class _TechFullScreenImageViewer extends ConsumerStatefulWidget {
  final String s3Path;
  final String title;

  const _TechFullScreenImageViewer({
    required this.s3Path,
    required this.title,
  });

  @override
  ConsumerState<_TechFullScreenImageViewer> createState() =>
      _TechFullScreenImageViewerState();
}

class _TechFullScreenImageViewerState
    extends ConsumerState<_TechFullScreenImageViewer> {
  bool _isLoading = true;
  String? _error;
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final s3Service = ref.read(s3FileServiceProvider);
      final bytes = await s3Service.downloadFile(filePath: widget.s3Path);

      if (bytes.length < 1000) {
        throw Exception('Invalid response from server');
      }

      setState(() {
        _imageBytes = bytes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to load image: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title, style: const TextStyle(fontSize: 14)),
        actions: [
          if (_imageBytes != null)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () => _downloadImage(),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  void _downloadImage() {
    if (kIsWeb && _imageBytes != null) {
      final blob = html.Blob([_imageBytes!]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      (html.AnchorElement(href: url)..setAttribute('download', widget.title))
          .click();
      html.Url.revokeObjectUrl(url);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloaded: ${widget.title}')),
      );
    }
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text('Loading image...', style: TextStyle(color: Colors.white)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.image_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text('Image Preview',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 18)),
              const SizedBox(height: 8),
              Text(widget.s3Path,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    if (_imageBytes != null) {
      return InteractiveViewer(
        panEnabled: true,
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(child: Image.memory(_imageBytes!)),
      );
    }

    return const Center(
        child: Text('No image data', style: TextStyle(color: Colors.white)));
  }
}

// ======================================
// FULLSCREEN PDF VIEWER (Same as Manager)
// ======================================

class _TechFullScreenPdfViewer extends ConsumerStatefulWidget {
  final String s3Path;
  final String title;

  const _TechFullScreenPdfViewer({
    required this.s3Path,
    required this.title,
  });

  @override
  ConsumerState<_TechFullScreenPdfViewer> createState() =>
      _TechFullScreenPdfViewerState();
}

class _TechFullScreenPdfViewerState
    extends ConsumerState<_TechFullScreenPdfViewer> {
  bool _isLoading = true;
  String? _error;
  Uint8List? _pdfBytes;
  String? _blobUrl;
  String? _localPdfPath;
  int _currentPage = 0;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      final s3Service = ref.read(s3FileServiceProvider);
      final bytes = await s3Service.downloadFile(filePath: widget.s3Path);

      if (bytes.length < 1000) {
        throw Exception('Invalid response from server');
      }

      if (kIsWeb) {
        _pdfBytes = bytes;
        _blobUrl = _createBlobUrl(bytes);
        setState(() => _isLoading = false);
      } else {
        final dir = await getTemporaryDirectory();
        final fileName = FileService.getFileName(widget.s3Path);
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);

        setState(() {
          _localPdfPath = file.path;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to load PDF: $e';
      });
    }
  }

  String _createBlobUrl(Uint8List bytes) {
    if (kIsWeb) {
      final blob = html.Blob([bytes], 'application/pdf');
      return html.Url.createObjectUrlFromBlob(blob);
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade900,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: const TextStyle(fontSize: 14)),
            if (_totalPages > 0 && !kIsWeb)
              Text('Page ${_currentPage + 1} of $_totalPages',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
          ],
        ),
        actions: [
          if (_pdfBytes != null)
            IconButton(
                icon: const Icon(Icons.download), onPressed: _downloadPdf),
        ],
      ),
      body: _buildBody(),
    );
  }

  void _downloadPdf() {
    if (kIsWeb && _pdfBytes != null) {
      final blob = html.Blob([_pdfBytes!], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      (html.AnchorElement(href: url)..setAttribute('download', widget.title))
          .click();
      html.Url.revokeObjectUrl(url);

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Downloaded: ${widget.title}')));
    }
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text('Loading PDF...', style: TextStyle(color: Colors.white)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.picture_as_pdf, size: 64, color: Colors.red.shade400),
              const SizedBox(height: 16),
              Text('PDF Preview',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 18)),
              const SizedBox(height: 8),
              Text(_error!,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    if (kIsWeb && _blobUrl != null) {
      ui.platformViewRegistry.registerViewFactory(
        'pdf-viewer-tech-${widget.s3Path.hashCode}',
        (int viewId) => html.IFrameElement()
          ..src = _blobUrl!
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%',
      );

      return HtmlElementView(
          viewType: 'pdf-viewer-tech-${widget.s3Path.hashCode}');
    }

    if (_localPdfPath != null) {
      return PDFView(
        filePath: _localPdfPath!,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: true,
        pageFling: true,
        onRender: (pages) => setState(() => _totalPages = pages ?? 0),
        onPageChanged: (page, _) => setState(() => _currentPage = page ?? 0),
        onError: (error) => setState(() => _error = error.toString()),
      );
    }

    return const Center(
        child: Text('No PDF data', style: TextStyle(color: Colors.white)));
  }
}
