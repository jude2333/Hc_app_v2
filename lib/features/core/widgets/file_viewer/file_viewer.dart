import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/features/theme/theme.dart';
import 'package:anderson_crm_flutter/features/core/services/file_service.dart';
import 'pdf_viewer_page.dart';
import 'image_viewer_page.dart';

/// A utility class for viewing files (PDF, images) with auto-detection
class FileViewer {
  /// View a file - automatically detects type and opens appropriate viewer
  static Future<void> view(
    BuildContext context, {
    required String s3Path,
    String? title,
    Uint8List? preloadedBytes,
    String? imageUrl,
  }) async {
    if (FileService.isPdf(s3Path)) {
      await PdfViewerPage.show(
        context,
        s3Path: s3Path,
        title: title,
        preloadedBytes: preloadedBytes,
      );
    } else if (FileService.isImage(s3Path)) {
      await ImageViewerPage.show(
        context,
        s3Path: s3Path,
        title: title,
        preloadedBytes: preloadedBytes,
        imageUrl: imageUrl,
      );
    } else {
      // Unknown file type - show message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Cannot preview: ${FileService.getFileName(s3Path)}')),
      );
    }
  }
}

/// Dialog showing list of files with View/Download options
class FilePickerDialog extends StatelessWidget {
  final List<String> files;
  final String title;
  final void Function(String path, String action)? onAction;

  const FilePickerDialog({
    super.key,
    required this.files,
    this.title = 'View / Download Files',
    this.onAction,
  });

  /// Show the file picker dialog
  static Future<void> show(
    BuildContext context, {
    required List<String> files,
    String title = 'View / Download Files',
    void Function(String path, String action)? onAction,
  }) {
    return showDialog(
      context: context,
      builder: (_) => FilePickerDialog(
        files: files,
        title: title,
        onAction: onAction,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.folder_open, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // File list
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: files.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final path = files[index];
                return _FileItem(
                  path: path,
                  onView: () {
                    Navigator.pop(context);
                    onAction?.call(path, 'view');
                  },
                  onDownload: () {
                    Navigator.pop(context);
                    onAction?.call(path, 'download');
                  },
                );
              },
            ),
          ),

          // Footer
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FileItem extends StatelessWidget {
  final String path;
  final VoidCallback? onView;
  final VoidCallback? onDownload;

  const _FileItem({
    required this.path,
    this.onView,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final fileName = FileService.getFileName(path);
    final isPdf = FileService.isPdf(path);
    final isImage = FileService.isImage(path);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // File name with icon
          Row(
            children: [
              Icon(
                isPdf
                    ? Icons.picture_as_pdf
                    : isImage
                        ? Icons.image
                        : Icons.insert_drive_file,
                size: 18,
                color: isPdf ? Colors.red : AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fileName,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onView,
                icon: const Icon(Icons.visibility, size: 16),
                label: const Text('View'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: onDownload,
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Download'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.success,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
