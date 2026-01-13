import 'dart:io';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:anderson_crm_flutter/features/theme/theme.dart';
import 'package:anderson_crm_flutter/features/core/widgets/file_viewer/file_viewer_exports.dart';
import 'package:anderson_crm_flutter/services/s3_file_service.dart';

/// Expanded content for search result details
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
          if (item['pres_photo'] != null) _buildPrescriptionSection(context),
          if (item['status'] == 'cancelled') _buildCancellationSection(),
          _buildProcessSteps(),
          SizedBox(height: AppSpacing.md),
          if (item['remarks'] != null) _buildRemarksSection(),
          if (item['server_status'] == 'Billed') _buildBillInfo(),
          if (item['report_path'] != null) _buildReportSection(context),
        ],
      ),
    );
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
            _TableHeader('Address'),
            _TableHeader('Pincode'),
            _TableHeader('Additional Info'),
            _TableHeader('Ref. By'),
            _TableHeader('Email'),
          ],
        ),
        TableRow(
          children: [
            _TableCell('${item['address'] ?? ''}'),
            _TableCell('${item['pincode'] ?? ''}'),
            _TableCell('${item['free_text'] ?? ''}'),
            _TableCell(_getRefBy()),
            _TableCell('${item['email'] ?? ''}'),
          ],
        ),
      ],
    );
  }

  String _getRefBy() {
    if (item['b2b_client_id'] != null) {
      return 'B2B: ${item['b2b_client_name'] ?? ''}';
    }
    return 'Dr. ${item['doctor_name'] ?? ''}';
  }

  Widget _buildPrescriptionSection(BuildContext context) {
    final path = item['pres_photo']?.toString() ?? '';
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

  Widget _buildProcessSteps() {
    final process = item['process'] as Map<String, dynamic>? ?? {};
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
        _buildStep('Step-1', process['first_step'], 'Delay'),
        _buildStep('Step-2', process['second_step'], 'Proforma'),
        _buildStep('Step-3', process['third_step'], 'Bill'),
        _buildStep('Step-4', process['fourth_step'], 'OTP'),
        _buildStep('Step-5', process['fifth_step'], 'Photos'),
      ],
    );
  }

  Widget _buildStep(String label, dynamic value, String context) {
    final isDone = value != null && value.toString().isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          _BorderedChip(
            label: label,
            color: isDone ? AppColors.primary : AppColors.textHint,
          ),
          SizedBox(width: AppSpacing.sm),
          Flexible(
            child: isDone
                ? _FilledChip(
                    label: '$context: $value',
                    color: AppColors.success,
                  )
                : Text(
                    'Pending',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textHint,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemarksSection() {
    final remarks = item['remarks']?.toString() ?? '';
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LabelChip(label: 'Remarks', color: AppColors.primary),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              remarks,
              style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
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
    final reportPath = item['report_path']?.toString() ?? '';
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        _LabelChip(label: 'Lab Result', color: AppColors.primary),
        _FilledChip(
          label: '${item['report_status'] ?? ''}',
          color: AppColors.success,
        ),
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

  /// View or download a file using the file picker dialog
  void _viewFile(BuildContext context, String path) {
    if (path.isEmpty) return;

    // Parse multiple files if comma-separated
    final files = path.contains(',')
        ? path.split(',').map((f) => f.trim()).toList()
        : [path];

    if (files.length == 1) {
      // Single file - open directly
      _openFileViewer(context, files.first);
    } else {
      // Multiple files - show picker
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

    // Show loading
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
        // For PDFs - open full screen PDF viewer
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
        // For images - show full screen viewer
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

// ============================================================================
// COMPACT CHIP WIDGETS (matching status chip style)
// ============================================================================

/// Bordered chip (outline only) - like Status chip
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

/// Filled chip (background color) - like Server Status chip
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

/// Label chip (for section headers)
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

/// Clickable action chip
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

class _TableHeader extends StatelessWidget {
  final String text;
  const _TableHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(AppSpacing.sm),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  const _TableCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(AppSpacing.sm),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }
}

/// Full screen image viewer that loads from S3
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Colors.grey)),
          ],
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
      child: Text('No image data', style: TextStyle(color: Colors.white)),
    );
  }
}

/// Full screen PDF viewer that loads from S3
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

  Future<void> _loadPdf() async {
    try {
      final s3Service = ref.read(s3FileServiceProvider);
      final bytes = await s3Service.downloadFile(filePath: widget.s3Path);

      if (bytes.length < 1000) {
        throw Exception('Invalid response from server');
      }

      if (kIsWeb) {
        _pdfBytes = bytes;
        final blob = html.Blob([bytes], 'application/pdf');
        _blobUrl = html.Url.createObjectUrlFromBlob(blob);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade900,
        foregroundColor: Colors.white,
        title: Text(widget.title, style: const TextStyle(fontSize: 14)),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (kIsWeb && _blobUrl != null) {
      // ignore: undefined_prefixed_name
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
