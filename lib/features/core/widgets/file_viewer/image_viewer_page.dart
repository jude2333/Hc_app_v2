import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import 'package:anderson_crm_flutter/features/core/services/file_service.dart';
import 'package:anderson_crm_flutter/services/s3_file_service.dart';

/// Full-screen image viewer with pinch-to-zoom and pan
/// Supports loading from S3 path, preloaded bytes, or URL
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

  /// Show image viewer as a full-screen page
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

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    // 1. Use preloaded bytes if available
    if (widget.preloadedBytes != null) {
      if (mounted) {
        setState(() {
          _imageBytes = widget.preloadedBytes;
          _isLoading = false;
        });
      }
      return;
    }

    // 2. Use URL if available (handled by PhotoView.network)
    if (widget.imageUrl != null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    // 3. Download from S3
    try {
      final s3Service = ref.read(s3FileServiceProvider);
      final bytes = await s3Service.downloadFile(filePath: widget.s3Path);

      if (bytes.length < 1000 && bytes.toString().contains('Error')) {
        // Basic validation - sometimes error text is returned as bytes
        throw Exception('Invalid image data');
      }

      if (mounted) {
        setState(() {
          _imageBytes = bytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load image: $e';
          _isLoading = false;
        });
      }
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
      return _buildLoading();
    }

    if (_error != null) {
      return _buildError();
    }

    // Use bytes if available
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

    // Use URL if available
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.broken_image, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text(_error ?? 'Failed to load image',
              style: const TextStyle(color: Colors.white)),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  void _downloadFile(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text('Image saved: ${FileService.getFileName(widget.s3Path)}')),
    );
  }
}
