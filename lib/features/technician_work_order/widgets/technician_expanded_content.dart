import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import 'package:anderson_crm_flutter/services/s3_file_service.dart';
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
  bool _isDownloading = false;

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
            _buildActionRow('Test Items', testItems != null ? 'View' : 'Nil',
                showAction: testItems != null,
                onAction:
                    testItems != null ? () => _viewTests(testItems) : null),
            if (isFinished && gpayRef == 'Later')
              _buildActionRow('GPay', 'Edit',
                  showAction: true, onAction: _editGPay)
            else
              _buildInfoRow('GPay', gpayRef.isEmpty ? 'Nil' : gpayRef),
            _buildActionRow('Proforma',
                proformaPath.isEmpty ? 'Nil' : _getFileName(proformaPath),
                showAction: proformaPath.isNotEmpty,
                onAction: proformaPath.isNotEmpty
                    ? () => _downloadFile(proformaPath)
                    : null),
            if (isFinished && !acceptRemittance)
              _buildRemittanceRow()
            else if (acceptRemittance)
              _buildInfoRow('Remittance', 'Accepted ✓',
                  valueColor: AppColors.success),
            if (labSampleAccepted)
              _buildInfoRow('Lab Samples', 'Accepted ✓',
                  valueColor: AppColors.success)
            else
              _buildLabSamplesRow(labSamplePics),
            _buildActionRow('Remarks', remarks.isEmpty ? 'Add' : 'Edit',
                showAction: true, onAction: () => _editRemarks(remarks)),
            if (reportStatus.isNotEmpty)
              _buildReportStatusRow(wo, reportStatus),
            _buildActionRow(
                'Report PDF', reportPath.isEmpty ? 'Nil' : 'Download',
                showAction: reportPath.isNotEmpty,
                onAction: reportPath.isNotEmpty
                    ? () => _downloadFile(reportPath)
                    : null,
                icon: reportPath.isNotEmpty ? Icons.cloud_download : null),
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
            IconButton(
                icon:
                    Icon(Icons.visibility, color: AppColors.success, size: 20),
                onPressed: () => _viewLabSamples(existingPics),
                visualDensity: VisualDensity.compact,
                tooltip: 'View/Download'),
        ],
      ),
    );
  }

  String _getFileName(String path) =>
      path.contains('/') ? path.substring(path.lastIndexOf('/') + 1) : path;

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

  void _viewLabSamples(String pics) {
    final files = pics.split(',').where((f) => f.trim().isNotEmpty).toList();
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text('Lab Sample Photos (${files.length})'),
              content: SingleChildScrollView(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: files
                        .map((f) => Card(
                              margin: EdgeInsets.only(bottom: AppSpacing.sm),
                              child: ListTile(
                                leading:
                                    Icon(Icons.image, color: AppColors.primary),
                                title: Text(_getFileName(f.trim()),
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 13)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                        icon: Icon(Icons.visibility,
                                            color: AppColors.primary, size: 20),
                                        tooltip: 'View',
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          _viewImage(f.trim());
                                        }),
                                    IconButton(
                                        icon: Icon(Icons.cloud_download,
                                            color: AppColors.success, size: 20),
                                        tooltip: 'Download',
                                        onPressed: () =>
                                            _downloadAndSave(f.trim())),
                                  ],
                                ),
                              ),
                            ))
                        .toList()),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx), child: Text('Close'))
              ],
            ));
  }

  Future<void> _viewImage(String path) async {
    try {
      setState(() => _isDownloading = true);
      final s3Service = ref.read(s3FileServiceProvider);
      final bytes = await s3Service.downloadFile(filePath: path);
      setState(() => _isDownloading = false);

      if (mounted) {
        final fileName = _getFileName(path);
        showDialog(
            context: context,
            builder: (ctx) => Dialog(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppBar(
                        title: Text(fileName, style: TextStyle(fontSize: 14)),
                        automaticallyImplyLeading: false,
                        actions: [
                          IconButton(
                              icon: Icon(Icons.close),
                              onPressed: () => Navigator.pop(ctx))
                        ],
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.7,
                          maxWidth: MediaQuery.of(context).size.width * 0.9,
                        ),
                        child: InteractiveViewer(
                            child: Image.memory(bytes, fit: BoxFit.contain)),
                      ),
                    ],
                  ),
                ));
      }
    } catch (e) {
      debugPrint('View error: $e');
      if (mounted) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to load: $e'),
            backgroundColor: AppColors.error));
      }
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

  Future<void> _downloadFile(String path) async {
    try {
      setState(() => _isDownloading = true);
      final s3Service = ref.read(s3FileServiceProvider);
      final bytes = await s3Service.downloadFile(filePath: path);
      setState(() => _isDownloading = false);

      if (mounted) {
        final fileName = _getFileName(path);
        final isImage = ['.jpg', '.jpeg', '.png', '.gif']
            .any((ext) => fileName.toLowerCase().endsWith(ext));
        if (isImage) {
          showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                    title: Text(fileName),
                    content: Image.memory(bytes),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Close'))
                    ],
                  ));
        } else {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Downloaded: $fileName')));
        }
      }
    } catch (e) {
      debugPrint('Download error: $e');
      if (mounted) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: AppColors.error));
      }
    }
  }
}
