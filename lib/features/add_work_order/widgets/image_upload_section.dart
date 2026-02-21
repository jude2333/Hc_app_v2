import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../features/theme/theme.dart';

class ImageUploadSection extends StatelessWidget {
  final List<XFile> images;
  final List<String> initialUrls;
  final Function(ImageSource) onPickImage;
  final Function(int)? onRemoveImage;
  final Function(int)? onRemoveExisting;

  const ImageUploadSection({
    super.key,
    this.images = const [],
    this.initialUrls = const [],
    required this.onPickImage,
    this.onRemoveImage,
    this.onRemoveExisting,
  });

  void _showImageSourceDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.photo_library, color: AppColors.primary),
                title: Text('Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  onPickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt, color: AppColors.primary),
                title: Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  onPickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasAny = images.isNotEmpty || initialUrls.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Existing (S3) prescription chips
        if (initialUrls.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (int i = 0; i < initialUrls.length; i++)
                Chip(
                  avatar: Icon(Icons.image_rounded,
                      size: 16, color: AppColors.success),
                  label: Text(
                    _extractFileName(initialUrls[i]),
                    style: TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                  deleteIcon:
                      Icon(Icons.close, size: 16, color: AppColors.error),
                  onDeleted: onRemoveExisting != null
                      ? () => onRemoveExisting!(i)
                      : null,
                  backgroundColor: AppColors.success.withOpacity(0.08),
                  side: BorderSide(color: AppColors.success.withOpacity(0.2)),
                ),
            ],
          ),

        // Newly picked image chips
        if (images.isNotEmpty) ...[
          if (initialUrls.isNotEmpty) SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (int i = 0; i < images.length; i++)
                Chip(
                  avatar: Icon(Icons.add_photo_alternate_rounded,
                      size: 16, color: AppColors.secondary),
                  label: Text(
                    images[i].name,
                    style: TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                  deleteIcon:
                      Icon(Icons.close, size: 16, color: AppColors.error),
                  onDeleted:
                      onRemoveImage != null ? () => onRemoveImage!(i) : null,
                  backgroundColor: AppColors.secondary.withOpacity(0.08),
                  side: BorderSide(color: AppColors.secondary.withOpacity(0.2)),
                ),
            ],
          ),
        ],

        SizedBox(height: hasAny ? AppSpacing.sm : 0),

        // Upload button — always visible so user can add more
        OutlinedButton.icon(
          icon: Icon(Icons.camera_alt_rounded, color: AppColors.secondary),
          label: Text(
            hasAny ? 'Add More' : 'Upload Prescription',
            style: TextStyle(color: AppColors.secondary),
          ),
          onPressed: () => _showImageSourceDialog(context),
          style: OutlinedButton.styleFrom(
            side: BorderSide(
                color: AppColors.secondary, style: BorderStyle.solid),
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
          ),
        ),
      ],
    );
  }

  /// Extract a readable filename from a full S3 path.
  String _extractFileName(String path) {
    final parts = path.split('/');
    final name = parts.isNotEmpty ? parts.last : path;
    // Remove timestamp prefix if present (e.g. "1738000000000_photo.jpg" → "photo.jpg")
    final underscoreIdx = name.indexOf('_');
    if (underscoreIdx > 0 && underscoreIdx < 15) {
      final prefix = name.substring(0, underscoreIdx);
      if (int.tryParse(prefix) != null) {
        return name.substring(underscoreIdx + 1);
      }
    }
    return name;
  }
}
