import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import 'package:anderson_crm_flutter/config/settings.dart';
import '../data/user_model.dart';
import '../providers/users_providers.dart';
import '../screens/addEditUser.dart';
import 'delete_user_dialog.dart';

/// Check if current user is a manager.
bool isManager(WidgetRef ref) {
  final storage = ref.read(storageServiceProvider);
  final mobile = storage.getFromSession("logged_in_mobile");
  return mobile == "9841541542";
}

/// Navigate to edit user page.
void editUser(BuildContext context, WidgetRef ref, User user) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) =>
          AddEditUserPage(userData: user.toJson(), isEdit: true),
    ),
  ).then((result) {
    if (result == true) {
      ref.refresh(usersListProvider);
    }
  });
}

/// Show delete user confirmation dialog.
void deleteUser(BuildContext context, WidgetRef ref, User user) {
  showDialog(
    context: context,
    builder: (context) => DeleteUserDialog(user: user),
  );
}

/// Download ID card file.
Future<void> downloadIdCard(BuildContext context, WidgetRef ref,
    String idLocation, String fileName) async {
  try {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Downloading: $fileName'),
          duration: const Duration(seconds: 1)),
    );

    List<String> locationParts = [];
    if (idLocation.contains(' | ')) {
      locationParts = idLocation.split(' | ');
    } else {
      locationParts = ['homecollection', idLocation];
    }

    final String bucketName = locationParts[0];
    final String key = locationParts[1];

    final storage = ref.read(storageServiceProvider);
    final jwtToken = storage.getFromSession("pg_admin");

    final downloadUrl = '${Settings.nodeUrl}/s3/get_file_v2';

    if (await canLaunch(downloadUrl)) {
      if (Platform.isAndroid || Platform.isIOS) {
        final requestData = {
          'bucket_name': bucketName,
          'key': key,
          'jwt_token': jwtToken,
        };
        if (context.mounted) {
          await _downloadForMobile(context, ref, requestData, fileName);
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Download not supported on this platform yet')),
          );
        }
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading file: $e')),
      );
    }
  }
}

Future<void> _downloadForMobile(BuildContext context, WidgetRef ref,
    Map<String, dynamic> requestData, String fileName) async {
  try {
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Storage permission denied')),
          );
        }
        return;
      }
    }

    Directory? directory;
    if (Platform.isAndroid) {
      directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        directory = await getExternalStorageDirectory();
      }
    } else if (Platform.isIOS) {
      directory = await getApplicationDocumentsDirectory();
    } else {
      directory = await getDownloadsDirectory();
    }

    if (directory == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find download directory')),
        );
      }
      return;
    }

    final filePath = '${directory.path}/$fileName';

    await Dio().post(
      '${Settings.nodeUrl}/s3/get_file_v2',
      data: requestData,
      options: Options(
        responseType: ResponseType.bytes,
      ),
      onReceiveProgress: (received, total) {
        if (total != -1) {
          final progress = (received / total * 100).toStringAsFixed(0);
          debugPrint('Download progress: $progress%');
        }
      },
    ).then((response) async {
      final file = File(filePath);
      await file.writeAsBytes(response.data);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File saved to: ${directory?.path}')),
        );
      }

      if (Platform.isAndroid || Platform.isIOS) {
        await OpenFile.open(filePath);
      }
    });
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving file: $e')),
      );
    }
  }
}
