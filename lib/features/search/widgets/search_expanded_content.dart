import 'dart:io';
import 'dart:typed_data';

import 'dart:html' as html;

import 'dart:ui_web' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:anderson_crm_flutter/features/theme/theme.dart';
import 'package:anderson_crm_flutter/features/core/widgets/file_viewer/file_viewer_exports.dart';
import 'package:anderson_crm_flutter/features/core/widgets/common/common_widgets.dart';
import 'package:anderson_crm_flutter/services/s3_file_service.dart';
import 'package:anderson_crm_flutter/components/time_line_page.dart';
import 'package:anderson_crm_flutter/models/work_order.dart';

class SearchExpandedContent extends StatelessWidget {
  final Map<String, dynamic> item;

  const SearchExpandedContent({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppPadding.card,
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(left: BorderSide(color: AppColors.primary, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoTable(context),
          SizedBox(height: AppSpacing.md),
          if (_hasPrescription()) _buildPrescriptionSection(context),
          if (item['status'] == 'cancelled') _buildCancellationSection(),
          _buildProcessSteps(context),
          SizedBox(height: AppSpacing.md),
          if (item['remarks'] != null) _buildRemarksSection(),
          if (item['server_status'] == 'Billed') _buildBillInfo(),
          if (item['report_path'] != null) _buildReportSection(context),
          SizedBox(height: AppSpacing.md),
          _buildTimelineButton(context),
        ],
      ),
    );
  }

  bool _hasPrescription() {
    final presPhoto = item['pres_photo'];
    return presPhoto != null && presPhoto.toString().isNotEmpty;
  }

  Widget _buildInfoTable(BuildContext context) {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(3),
        3: FlexColumnWidth(2),
        4: FlexColumnWidth(2),
      },
      border: TableBorder.all(color: AppColors.tableBorder),
      children: [
        TableRow(
          decoration: BoxDecoration(color: AppColors.surfaceAlt),
          children: const [
            WOTableHeader('Address'),
            WOTableHeader('Pincode'),
            WOTableHeader('Additional Info'),
            WOTableHeader('Ref. By'),
            WOTableHeader('Email'),
          ],
        ),
        TableRow(
          children: [
            WOTableCell('${item['address'] ?? ''}'),
            WOTableCell('${item['pincode'] ?? ''}'),
            WOTableCell('${item['free_text'] ?? ''}'),
            WOTableCell(_getRefBy()),
            WOTableCell('${item['email'] ?? ''}'),
          ],
        ),
      ],
    );
  }

  String _getRefBy() {
    final b2bId = item['b2b_client_id'];
    if (b2bId != null && b2bId != 0 && b2bId != '') {
      return 'B2B: ${item['b2b_client_name'] ?? ''}';
    }
    final doctor = item['doctor_name']?.toString() ?? '';
    if (doctor.isNotEmpty) {
      return 'Dr. $doctor';
    }
    return 'Not Specified';
  }

  Widget _buildTimelineButton(BuildContext context) {
    return _ActionLinkChip(
      label: 'Time Line',
      color: AppColors.secondary,
      onTap: () {
        try {
          final workOrder = WorkOrder.fromDocMap(item);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TimeLinePage(workOrder: workOrder),
            ),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error loading timeline: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }

  Widget _buildPrescriptionSection(BuildContext context) {
    final path = item['pres_photo']?.toString() ?? '';
    if (path.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _LabelChip(label: 'Prescription', color: AppColors.error),
          _ActionLinkChip(
            label: _getName(path),
            color: AppColors.secondary,
            onTap: () => _viewFile(context, path),
          ),
        ],
      ),
    );
  }

  Widget _buildCancellationSection() {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: _FilledChip(
        label: 'Cancelled: ${item['cancel_reason'] ?? 'N/A'}',
        color: AppColors.error,
      ),
    );
  }

  Widget _buildProcessSteps(BuildContext context) {
    final process = item['process'] as Map<String, dynamic>? ?? {};
    bool isStepDone(String? key) =>
        process[key] != null && process[key].toString().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'HC Process Status:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: AppSpacing.xs),
        _buildGenericStep(
          'Step-1',
          isStepDone('first_step')
              ? 'Delay: ${process['first_step']}'
              : 'Pending / No Delay',
          isDone: isStepDone('first_step'),
        ),
        SizedBox(height: AppSpacing.xs),
        _buildProformaStep(context, process['second_step']),
        SizedBox(height: AppSpacing.xs),
        _buildGenericStep(
          'Step-3',
          isStepDone('third_step')
              ? 'Bill: ${process['third_step']}'
              : 'Pending',
          isDone: isStepDone('third_step'),
        ),
        SizedBox(height: AppSpacing.xs),
        _buildGenericStep(
          'Step-4',
          isStepDone('fourth_step')
              ? 'OTP: ${process['fourth_step']}'
              : 'Pending',
          isDone: isStepDone('fourth_step'),
        ),
        SizedBox(height: AppSpacing.xs),
        _buildPrescriptionPhotoStep(context, process['fifth_step']),
      ],
    );
  }

  Widget _buildGenericStep(String label, String content,
      {bool isDone = false}) {
    return Row(
      children: [
        _BorderedChip(
          label: label,
          color: isDone ? AppColors.primary : AppColors.textHint,
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: isDone
              ? _FilledChip(label: content, color: AppColors.success)
              : Text(
                  content,
                  style: TextStyle(fontSize: 11, color: AppColors.textHint),
                  overflow: TextOverflow.ellipsis,
                ),
        ),
      ],
    );
  }

  Widget _buildProformaStep(BuildContext context, dynamic stepData) {
    final isDone = stepData != null && stepData.toString().isNotEmpty;
    String statusText = 'Pending';

    if (isDone) {
      final b2bId = item['b2b_client_id'];
      final credit = item['credit'];

      if (b2bId != null && b2bId != 0 && b2bId != '') {
        statusText = 'Not Sent (B2B)';
      } else if (credit == 1) {
        statusText = 'Not Sent (Credit)';
      } else if (credit == 2) {
        statusText = 'Not Sent (Trial)';
      } else {
        statusText = 'Sent';
      }
    }

    return Row(
      children: [
        _BorderedChip(
          label: 'Step-2',
          color: isDone ? AppColors.primary : AppColors.textHint,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          'Proforma:',
          style: TextStyle(
            fontSize: 11,
            color: isDone ? AppColors.textPrimary : AppColors.textHint,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        if (isDone) ...[
          _FilledChip(
            label: statusText,
            color: statusText == 'Sent' ? AppColors.success : AppColors.error,
          ),
          const SizedBox(width: AppSpacing.xs),
          _ActionLinkChip(
            label: 'View PDF',
            color: AppColors.secondary,
            onTap: () => _viewFile(context, stepData.toString()),
          ),
        ],
        if (!isDone)
          Text('Pending',
              style: TextStyle(fontSize: 11, color: AppColors.textHint)),
      ],
    );
  }

  Widget _buildPrescriptionPhotoStep(BuildContext context, dynamic stepData) {
    final isDone = stepData != null && stepData.toString().isNotEmpty;
    final path = stepData?.toString() ?? '';

    return Row(
      children: [
        _BorderedChip(
          label: 'Step-5',
          color: isDone ? AppColors.primary : AppColors.textHint,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          'Photos:',
          style: TextStyle(
            fontSize: 11,
            color: isDone ? AppColors.textPrimary : AppColors.textHint,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        if (isDone)
          _ActionLinkChip(
            label: _getPrescriptionFileNames(path),
            color: AppColors.secondary,
            onTap: () => _viewFile(context, path),
          ),
        if (!isDone)
          Text('Pending',
              style: TextStyle(fontSize: 11, color: AppColors.textHint)),
      ],
    );
  }

  Widget _buildRemarksSection() {
    final remarks = item['remarks']?.toString() ?? '';
    final hasRemarks = remarks.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LabelChip(label: 'Remarks', color: AppColors.primary),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              hasRemarks ? remarks : 'No Remarks',
              style: TextStyle(
                fontSize: 12,
                color: hasRemarks ? AppColors.textPrimary : AppColors.textHint,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillInfo() {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: [
          _FilledChip(
            label: 'Bill: ${item['bill_number'] ?? ''}',
            color: AppColors.secondary,
          ),
          _FilledChip(
            label: 'Lab: ${item['lab_number'] ?? ''}',
            color: AppColors.secondary,
          ),
        ],
      ),
    );
  }

  Widget _buildReportSection(BuildContext context) {
    final status = '${item['report_status'] ?? ''}';
    final reportPath = item['report_path']?.toString() ?? '';
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        _LabelChip(label: 'Lab Result', color: AppColors.primary),
        _FilledChip(label: status, color: AppColors.success),
        _ActionLinkChip(
          label: 'Report PDF',
          color: AppColors.secondary,
          onTap: () => _viewFile(context, reportPath),
        ),
      ],
    );
  }

  String _getName(dynamic name) {
    if (name == null) return '';
    String n = name.toString();
    return n.contains('/') ? n.substring(n.lastIndexOf('/') + 1) : n;
  }

  String _getPrescriptionFileNames(String name) {
    if (name.isEmpty) return '';
    List<String> a = name.contains(',') ? name.split(',') : [name];
    return a.length > 1 ? '${a.length} files' : _getName(name);
  }

  void _viewFile(BuildContext context, String path) {
    if (path.isEmpty) return;

    final files = path.contains(',')
        ? path.split(',').map((f) => f.trim()).toList()
        : [path];

    if (files.length == 1) {
      _openFileViewer(context, files.first);
    } else {
      FilePickerDialog.show(
        context,
        files: files,
        title: 'View / Download Files',
        onAction: (selectedPath, action) {
          if (action == 'view') {
            _openFileViewer(context, selectedPath);
          } else {
            _downloadFile(context, selectedPath);
          }
        },
      );
    }
  }

  void _openFileViewer(BuildContext context, String path) async {
    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text('Loading ${FileService.getFileName(path)}...'),
          ],
        ),
        duration: const Duration(seconds: 30),
      ),
    );

    try {
      final fileName = FileService.getFileName(path);
      messenger.hideCurrentSnackBar();

      if (FileService.isPdf(path)) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _FullScreenPdfViewer(
              s3Path: path,
              title: fileName,
            ),
          ),
        );
      } else if (FileService.isImage(path)) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _FullScreenImageViewer(
              s3Path: path,
              title: fileName,
            ),
          ),
        );
      }
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _downloadFile(BuildContext context, String path) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Download started: ${FileService.getFileName(path)}'),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
  }
}

class _BorderedChip extends StatelessWidget {
  final String label;
  final Color color;

  const _BorderedChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _FilledChip extends StatelessWidget {
  final String label;
  final Color color;

  const _FilledChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
        softWrap: true,
      ),
    );
  }
}

class _LabelChip extends StatelessWidget {
  final String label;
  final Color color;

  const _LabelChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ActionLinkChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionLinkChip({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.open_in_new, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullScreenImageViewer extends ConsumerStatefulWidget {
  final String s3Path;
  final String title;

  const _FullScreenImageViewer({
    required this.s3Path,
    required this.title,
  });

  @override
  ConsumerState<_FullScreenImageViewer> createState() =>
      _FullScreenImageViewerState();
}

class _FullScreenImageViewerState
    extends ConsumerState<_FullScreenImageViewer> {
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
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Downloading ${widget.title}...')),
              );
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
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
              Text(
                'Image Preview',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                widget.s3Path,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                textAlign: TextAlign.center,
              ),
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
        child: Center(
          child: Image.memory(_imageBytes!),
        ),
      );
    }

    return const Center(
      child: Text('No image data', style: TextStyle(color: Colors.white)),
    );
  }
}

class _FullScreenPdfViewer extends ConsumerStatefulWidget {
  final String s3Path;
  final String title;

  const _FullScreenPdfViewer({
    required this.s3Path,
    required this.title,
  });

  @override
  ConsumerState<_FullScreenPdfViewer> createState() =>
      _FullScreenPdfViewerState();
}

class _FullScreenPdfViewerState extends ConsumerState<_FullScreenPdfViewer> {
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

  @override
  void dispose() {
    if (_blobUrl != null && kIsWeb) {}
    super.dispose();
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
        setState(() {
          _isLoading = false;
        });
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
              Text(
                'Page ${_currentPage + 1} of $_totalPages',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Downloading ${widget.title}...')),
              );
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
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
              const Icon(Icons.picture_as_pdf, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'PDF Preview',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                widget.s3Path,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                textAlign: TextAlign.center,
              ),
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
        'pdf-viewer-${widget.s3Path.hashCode}',
        (int viewId) => html.IFrameElement()
          ..src = _blobUrl!
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%',
      );
      return HtmlElementView(viewType: 'pdf-viewer-${widget.s3Path.hashCode}');
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
      child: Text('No PDF data', style: TextStyle(color: Colors.white)),
    );
  }
}
