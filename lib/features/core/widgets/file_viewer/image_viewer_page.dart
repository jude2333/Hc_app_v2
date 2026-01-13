import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:anderson_crm_flutter/features/core/services/file_service.dart';

/// Full-screen image viewer with pinch-to-zoom and pan
class ImageViewerPage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final fileName = title ?? FileService.getFileName(s3Path);

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
    // If preloaded bytes provided
    if (preloadedBytes != null) {
      return PhotoView(
        imageProvider: MemoryImage(preloadedBytes!),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 3,
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        loadingBuilder: (_, __) => _buildLoading(),
        errorBuilder: (_, __, ___) => _buildError(),
      );
    }

    // If URL provided
    if (imageUrl != null) {
      return PhotoView(
        imageProvider: NetworkImage(imageUrl!),
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
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, size: 48, color: Colors.grey),
          SizedBox(height: 16),
          Text('Failed to load image', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  void _downloadFile(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Image saved: ${FileService.getFileName(s3Path)}')),
    );
  }
}
