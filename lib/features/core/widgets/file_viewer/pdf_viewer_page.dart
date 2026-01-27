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
import 'package:anderson_crm_flutter/features/core/services/file_service.dart';
import 'package:anderson_crm_flutter/services/s3_file_service.dart';

class PdfViewerPage extends ConsumerStatefulWidget {
  final String s3Path;
  final String? title;
  final Uint8List? preloadedBytes;

  const PdfViewerPage({
    super.key,
    required this.s3Path,
    this.title,
    this.preloadedBytes,
  });

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
  ConsumerState<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends ConsumerState<PdfViewerPage> {
  bool _isLoading = true;
  String? _localPath;
  String? _error;
  int _currentPage = 0;
  int _totalPages = 0;

  static final Set<String> _registeredViewTypes = {};

  String? _blobUrl;
  Uint8List? _pdfBytes;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  @override
  void dispose() {
    if (_blobUrl != null && kIsWeb) {
      html.Url.revokeObjectUrl(_blobUrl!);
    }
    super.dispose();
  }

  Future<void> _loadPdf() async {
    try {
      Uint8List? bytes = widget.preloadedBytes;

      if (bytes == null) {
        final s3Service = ref.read(s3FileServiceProvider);
        bytes = await s3Service.downloadFile(filePath: widget.s3Path);
      }

      if (bytes.length < 1000 && bytes.toString().contains('Error')) {
        throw Exception('Invalid PDF data');
      }

      _pdfBytes = bytes;

      if (kIsWeb) {
        _blobUrl = _createBlobUrl(bytes);
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        final dir = await getTemporaryDirectory();
        final fileName = FileService.getFileName(widget.s3Path);
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);

        if (mounted) {
          setState(() {
            _localPath = file.path;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load PDF: $e';
          _isLoading = false;
        });
      }
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
            if (_totalPages > 0 && !kIsWeb)
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

    if (kIsWeb && _blobUrl != null) {
      final String viewType = 'pdf-viewer-${widget.s3Path.hashCode}';

      if (!_registeredViewTypes.contains(viewType)) {
        ui.platformViewRegistry.registerViewFactory(
          viewType,
          (int viewId) => html.IFrameElement()
            ..src = _blobUrl!
            ..style.border = 'none'
            ..style.width = '100%'
            ..style.height = '100%',
        );
        _registeredViewTypes.add(viewType);
      }

      return HtmlElementView(
        viewType: viewType,
      );
    }

    if (_localPath == null) {
      return const Center(
          child: Text('Unexpected error: No file path',
              style: TextStyle(color: Colors.white)));
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
    if (kIsWeb) {
      if (_pdfBytes != null) {
        final blob = html.Blob([_pdfBytes!], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', FileService.getFileName(widget.s3Path))
          ..click();
        html.Url.revokeObjectUrl(url);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Downloading: ${FileService.getFileName(widget.s3Path)}')),
        );
      }
    } else {
      if (_localPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('PDF saved: ${FileService.getFileName(widget.s3Path)}')),
        );
      }
    }
  }
}
