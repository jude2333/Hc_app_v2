/// File viewer components for viewing PDFs, images, and downloading files
///
/// Usage:
/// ```dart
/// import 'package:anderson_crm_flutter/features/core/widgets/file_viewer/file_viewer_exports.dart';
///
/// // View a single file (auto-detects type)
/// FileViewer.view(context, s3Path: 'bucket/path/to/file.pdf');
///
/// // Show file picker dialog with multiple files
/// FilePickerDialog.show(
///   context,
///   files: ['file1.pdf', 'file2.jpg'],
///   onAction: (path, action) => action == 'view' ? _view(path) : _download(path),
/// );
/// ```
library file_viewer;

export 'file_viewer.dart';
export 'pdf_viewer_page.dart';
export 'image_viewer_page.dart';
export 'package:anderson_crm_flutter/features/core/services/file_service.dart';
