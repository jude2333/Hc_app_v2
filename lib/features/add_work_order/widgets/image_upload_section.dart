import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../features/theme/theme.dart';

class ImageUploadSection extends StatelessWidget {
  final XFile? image;
  final String? initialUrl;
  final Function(ImageSource) onPickImage;

  const ImageUploadSection({
    super.key,
    required this.image,
    this.initialUrl,
    required this.onPickImage,
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
    final hasImage =
        image != null || (initialUrl != null && initialUrl!.isNotEmpty);

    if (!hasImage) {
      return OutlinedButton.icon(
        icon: Icon(Icons.camera_alt_rounded, color: AppColors.secondary),
        label: Text('Upload Prescription',
            style: TextStyle(color: AppColors.secondary)),
        onPressed: () => _showImageSourceDialog(context),
        style: OutlinedButton.styleFrom(
          side:
              BorderSide(color: AppColors.secondary, style: BorderStyle.solid),
          padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: AppRadius.smAll,
          child: Container(
            width: double.infinity,
            height: 160,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: AppRadius.smAll,
            ),
            child: image != null
                ? (kIsWeb
                    ? Image.network(image!.path, fit: BoxFit.cover)
                    : Image.file(File(image!.path), fit: BoxFit.cover))
                : (initialUrl != null && initialUrl!.isNotEmpty)
                    ? Image.network(initialUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Center(
                              child: Icon(Icons.broken_image,
                                  color: AppColors.textHint),
                            ))
                    : Center(
                        child: Text('No Image',
                            style: TextStyle(color: AppColors.textHint)),
                      ),
          ),
        ),
        SizedBox(height: AppSpacing.sm),
        TextButton.icon(
          icon: Icon(Icons.refresh, size: 16),
          label: Text('Change'),
          onPressed: () => _showImageSourceDialog(context),
        ),
      ],
    );
  }
}
