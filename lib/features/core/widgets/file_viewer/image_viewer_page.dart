import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import 'package:anderson_crm_flutter/features/core/services/file_service.dart';
import 'package:anderson_crm_flutter/services/s3_file_service.dart';

class ImageViewerPage extends ConsumerStatefulWidget {
  final String s3Path;
  final String? title;
  final Uint8List? preloadedBytes;
  final String? imageUrl;

  const ImageViewerPage({
    super.key,
    required this.s3Path,
    this.title,
    this.preloadedBytes,
    this.imageUrl,
  });

  static Future<void> show(
    BuildContext context, {
    required String s3Path,
    String? title,
    Uint8List? preloadedBytes,
    String? imageUrl,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImageViewerPage(
          s3Path: s3Path,
          title: title,
          preloadedBytes: preloadedBytes,
          imageUrl: imageUrl,
        ),
      ),
    );
  }

  @override
  ConsumerState<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends ConsumerState<ImageViewerPage> {
  bool _isLoading = true;
  String? _error;
  Uint8List? _imageBytes;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Use preloaded bytes if available
    if (widget.preloadedBytes != null) {
      if (mounted) {
        setState(() {
          _imageBytes = widget.preloadedBytes;
          _isLoading = false;
        });
      }
      return;
    }

    // Use URL if available (no bytes needed)
    if (widget.imageUrl != null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    // Download from S3
    try {
      final s3Service = ref.read(s3FileServiceProvider);
      final bytes = await s3Service.downloadFile(filePath: widget.s3Path);

      // Validate image content
      if (!S3FileService.isValidImage(bytes)) {
        debugPrint(
            '[ImageViewer] Invalid image data: ${bytes.length} bytes, header: ${bytes.take(4).toList()}');
        throw S3DownloadException(
          'The downloaded file is not a valid image.',
          isNotFound: true,
        );
      }

      if (mounted) {
        setState(() {
          _imageBytes = bytes;
          _isLoading = false;
        });
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
          _error = 'Failed to load image. Please try again.';
          _isLoading = false;
        });
      }
      debugPrint('[ImageViewer] Load error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.title ?? FileService.getFileName(widget.s3Path);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(fileName, style: const TextStyle(fontSize: 16)),
        actions: [
          if (_imageBytes != null)
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
      return _buildLoading();
    }

    if (_error != null) {
      return _buildError();
    }

    if (_imageBytes != null) {
      return PhotoView(
        imageProvider: MemoryImage(_imageBytes!),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 3,
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        loadingBuilder: (_, __) => _buildLoading(),
        errorBuilder: (_, __, ___) => _buildError(),
      );
    }

    if (widget.imageUrl != null) {
      return PhotoView(
        imageProvider: NetworkImage(widget.imageUrl!),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 3,
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        loadingBuilder: (_, __) => _buildLoading(),
        errorBuilder: (_, __, ___) => _buildError(),
      );
    }

    return _buildError();
  }

  Widget _buildLoading() {
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

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.broken_image, size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Failed to load image',
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
              onPressed: _isLoading ? null : _loadImage,
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
    if (_imageBytes == null) return;

    setState(() => _isDownloading = true);

    try {
      await FileService.saveOrOpenFile(
        context,
        bytes: _imageBytes!,
        fileName: FileService.getFileName(widget.s3Path),
        mimeType:
            'image/${FileService.getExtension(widget.s3Path).replaceAll('.', '')}',
      );
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }
}
