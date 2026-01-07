import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/hc_process_provider.dart';
import '../providers/hc_process_controller.dart';

class HCStepPrescription extends ConsumerStatefulWidget {
  final String workOrderId;

  const HCStepPrescription({Key? key, required this.workOrderId})
      : super(key: key);

  @override
  ConsumerState<HCStepPrescription> createState() => _HCStepPrescriptionState();
}

class _HCStepPrescriptionState extends ConsumerState<HCStepPrescription> {
  final ImagePicker _imagePicker = ImagePicker();

  Future<void> _pickAndUpload() async {
    final state = ref.read(hcProcessProvider(widget.workOrderId));
    final controller =
        ref.read(hcProcessControllerProvider(widget.workOrderId));

    ImageSource? source;
    XFile? pickedFile;
    Uint8List? fileBytes;

    if (!kIsWeb) {
      source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
      if (source == null) return;

      pickedFile =
          await _imagePicker.pickImage(source: source, imageQuality: 85);
    } else {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      if (result == null) return;
      fileBytes = result.files.single.bytes;
      pickedFile = XFile.fromData(fileBytes!, name: result.files.single.name);
    }

    if (pickedFile == null) return;

    try {
      await controller.uploadPrescription(
        source: source ?? ImageSource.gallery,
        webBytes: fileBytes,
        pickedFile: pickedFile,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.offlineMode
                ? 'Photo saved offline!'
                : 'Photo uploaded successfully!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hcProcessProvider(widget.workOrderId));
    final notifier = ref.read(hcProcessProvider(widget.workOrderId).notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Upload Prescription Photos',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Offline Mode'),
          subtitle: Text(
            state.offlineMode
                ? 'Photos saved locally, sync when online'
                : 'Upload directly to server',
          ),
          value: state.offlineMode,
          activeColor: Colors.orange,
          onChanged: (value) => notifier.setOfflineMode(value),
        ),
        const SizedBox(height: 12),
        if (state.offlineMode)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.cloud_off, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Photos will be saved offline and uploaded automatically when network is available.',
                    style:
                        TextStyle(color: Colors.orange.shade800, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ElevatedButton.icon(
          onPressed: state.isLoading ? null : _pickAndUpload,
          style: ElevatedButton.styleFrom(
            backgroundColor: state.offlineMode ? Colors.orange : Colors.blue,
          ),
          icon: Icon(state.offlineMode ? Icons.save : Icons.cloud_upload),
          label: Text(
            state.isLoading
                ? 'Processing...'
                : (state.offlineMode ? 'Save Photo Offline' : 'Upload Photo'),
          ),
        ),
        const SizedBox(height: 16),
        if (state.uploadedPhotoPaths.isNotEmpty) ...[
          Text(
            '${state.offlineMode ? "Saved" : "Uploaded"} Photos:',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: state.uploadedPhotos.asMap().entries.map((e) {
              return Chip(
                avatar: Icon(
                  state.offlineMode ? Icons.cloud_off : Icons.check,
                  size: 16,
                  color: Colors.white,
                ),
                backgroundColor:
                    state.offlineMode ? Colors.orange : Colors.green,
                label: Text('Photo ${e.key + 1}: ${e.value}'),
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: () => notifier.removePhoto(e.key),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
