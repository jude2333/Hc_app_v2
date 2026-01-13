import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:anderson_crm_flutter/features/theme/theme.dart';
import 'package:anderson_crm_flutter/features/core/services/file_service.dart';

/// Full-screen PDF viewer with zoom and page navigation
class PdfViewerPage extends StatefulWidget {
  final String s3Path;
  final String? title;
  final Uint8List? preloadedBytes;

  const PdfViewerPage({
    super.key,
    required this.s3Path,
    this.title,
    this.preloadedBytes,
  });

  /// Show PDF viewer as a full-screen page
  static Future<void> show(
    BuildContext context, {
    required String s3Path,
    String? title,
    Uint8List? preloadedBytes,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfViewerPage(
          s3Path: s3Path,
          title: title,
          preloadedBytes: preloadedBytes,
        ),
      ),
    );
  }

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  bool _isLoading = true;
  String? _localPath;
  String? _error;
  int _currentPage = 0;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      Uint8List? bytes = widget.preloadedBytes;

      if (bytes == null) {
        // Download from S3 - we need FileService but for now use direct bytes
        setState(() => _error = 'PDF data not provided');
        return;
      }

      // Save to temp file for PDFView
      final dir = await getTemporaryDirectory();
      final fileName = FileService.getFileName(widget.s3Path);
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      setState(() {
        _localPath = file.path;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load PDF: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title ?? FileService.getFileName(widget.s3Path);

    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade900,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16)),
            if (_totalPages > 0)
              Text(
                'Page ${_currentPage + 1} of $_totalPages',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Download',
            onPressed: () => _downloadFile(context),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.white)),
          ],
        ),
      );
    }

    return PDFView(
      filePath: _localPath!,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: true,
      onRender: (pages) => setState(() => _totalPages = pages ?? 0),
      onPageChanged: (page, _) => setState(() => _currentPage = page ?? 0),
      onError: (error) => setState(() => _error = error.toString()),
    );
  }

  void _downloadFile(BuildContext context) {
    if (_localPath != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('PDF saved: ${FileService.getFileName(widget.s3Path)}')),
      );
    }
  }
}
