import 'dart:convert';
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
  bool _isDownloading = false;

  /// Cache blob URLs by viewType key so they survive across widget instances.
  /// Once registered, a platformViewFactory can never be updated, so the blob
  /// URL it references must remain valid.
  static final Map<String, String> _blobUrlCache = {};

  /// Track which viewType factories are actually registered (one-shot per key).
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
    // Do NOT revoke _blobUrl here.
    // registerViewFactory is permanent — the IFrame factory closure
    // captures _blobUrl, so revoking it breaks reopens of the same PDF.
    super.dispose();
  }

  Future<void> _loadPdf() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      Uint8List? bytes = widget.preloadedBytes;

      if (bytes == null) {
        final s3Service = ref.read(s3FileServiceProvider);
        bytes = await s3Service.downloadFile(filePath: widget.s3Path);
      }

      // Validate PDF content
      if (!S3FileService.isValidPdf(bytes)) {
        debugPrint(
            '[PdfViewer] Invalid PDF data: ${bytes.length} bytes, header: ${bytes.take(4).toList()}');
        throw S3DownloadException(
          'The downloaded file is not a valid PDF.',
          isNotFound: true,
        );
      }

      _pdfBytes = bytes;

      if (kIsWeb) {
        final viewType = 'pdf-viewer-${widget.s3Path.hashCode}';

        // Reuse existing blob URL if the factory was previously registered
        if (_blobUrlCache.containsKey(viewType)) {
          _blobUrl = _blobUrlCache[viewType];
        } else {
          _blobUrl = _createWebViewerUrl(bytes);
          _blobUrlCache[viewType] = _blobUrl!;
        }

        // Register the factory ONCE per viewType
        if (!_registeredViewTypes.contains(viewType)) {
          final urlForFactory = _blobUrl!;
          ui.platformViewRegistry.registerViewFactory(
            viewType,
            (int viewId) => html.IFrameElement()
              ..src = urlForFactory
              ..style.border = 'none'
              ..style.width = '100%'
              ..style.height = '100%'
              ..setAttribute('allow', 'fullscreen')
              ..setAttribute(
                  'sandbox', 'allow-scripts allow-same-origin allow-popups'),
          );
          _registeredViewTypes.add(viewType);
        }

        if (mounted) {
          setState(() => _isLoading = false);
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
    } on S3DownloadException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load PDF. Please try again.';
          _isLoading = false;
        });
      }
      debugPrint('[PdfViewer] Load error: $e');
    }
  }

  /// Creates a blob URL containing an HTML page with PDF.js that renders
  /// the PDF on a canvas. Works on ALL browsers including mobile.
  String _createWebViewerUrl(Uint8List bytes) {
    final base64Data = base64Encode(bytes);
    final htmlContent = _buildPdfJsHtml(base64Data);
    final blob = html.Blob([htmlContent], 'text/html');
    return html.Url.createObjectUrlFromBlob(blob);
  }

  /// Builds a self-contained HTML page that uses PDF.js (CDN) to render
  /// the PDF from base64 data. Renders all pages as scrollable canvases.
  String _buildPdfJsHtml(String base64Data) {
    return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=3, user-scalable=yes">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { background: #525659; }
  #container { display: flex; flex-direction: column; align-items: center; padding: 8px 0; }
  canvas { display: block; margin: 6px auto; box-shadow: 0 2px 8px rgba(0,0,0,0.3); background: white; }
  .msg { color: #ccc; font-family: -apple-system, sans-serif; padding: 40px; text-align: center; font-size: 15px; }
  .err { color: #ff6b6b; }
</style>
</head>
<body>
<div id="container"><div class="msg">Rendering PDF\u2026</div></div>
<script src="https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.min.js"></script>
<script>
pdfjsLib.GlobalWorkerOptions.workerSrc =
  "https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js";

var raw = atob("$base64Data");
var uint8 = new Uint8Array(raw.length);
for (var i = 0; i < raw.length; i++) uint8[i] = raw.charCodeAt(i);

pdfjsLib.getDocument({data: uint8}).promise.then(function(pdf) {
  var container = document.getElementById("container");
  container.innerHTML = "";
  var rendered = 0;
  for (var p = 1; p <= pdf.numPages; p++) {
    (function(pageNum) {
      pdf.getPage(pageNum).then(function(page) {
        var vp1 = page.getViewport({scale: 1});
        var scale = Math.min((window.innerWidth - 16) / vp1.width, 2.0);
        var viewport = page.getViewport({scale: scale});
        var canvas = document.createElement("canvas");
        canvas.width = viewport.width;
        canvas.height = viewport.height;
        canvas.style.order = pageNum;
        container.appendChild(canvas);
        page.render({canvasContext: canvas.getContext("2d"), viewport: viewport});
      });
    })(p);
  }
}).catch(function(e) {
  document.getElementById("container").innerHTML =
    '<div class="msg err">Failed to load PDF: ' + e.message + "</div>";
});
</script>
</body>
</html>
''';
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
          if (_pdfBytes != null)
            _isDownloading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    ),
                  )
                : IconButton(
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
      return _buildError();
    }

    if (kIsWeb && _blobUrl != null) {
      // Factory was already registered in _loadPdf() — just reference it.
      final viewType = 'pdf-viewer-${widget.s3Path.hashCode}';
      return HtmlElementView(viewType: viewType);
    }

    if (_localPath == null) {
      return _buildError();
    }

    return PDFView(
      filePath: _localPath!,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: true,
      onRender: (pages) => setState(() => _totalPages = pages ?? 0),
      onPageChanged: (page, _) => setState(() => _currentPage = page ?? 0),
      onError: (error) {
        debugPrint('[PdfViewer] PDFView render error: $error');
        setState(
            () => _error = 'Failed to render PDF. The file may be corrupted.');
      },
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.picture_as_pdf, size: 56, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Failed to load PDF',
              style: const TextStyle(color: Colors.white, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              FileService.getFileName(widget.s3Path),
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _loadPdf,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadFile(BuildContext context) async {
    if (_pdfBytes == null) return;

    setState(() => _isDownloading = true);

    try {
      await FileService.saveOrOpenFile(
        context,
        bytes: _pdfBytes!,
        fileName: FileService.getFileName(widget.s3Path),
        mimeType: 'application/pdf',
      );
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }
}
