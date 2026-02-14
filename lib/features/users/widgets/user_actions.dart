import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:anderson_crm_flutter/providers/storage_provider.dart';
import 'package:anderson_crm_flutter/features/core/services/file_service.dart';
import '../data/user_model.dart';
import '../providers/users_providers.dart';
import '../screens/addEditUser.dart';
import 'delete_user_dialog.dart';

bool isManager(WidgetRef ref) {
  final storage = ref.read(storageServiceProvider);
  final mobile = storage.getFromSession("logged_in_mobile");
  return mobile == "9841541542";
}

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

void deleteUser(BuildContext context, WidgetRef ref, User user) {
  showDialog(
    context: context,
    builder: (context) => DeleteUserDialog(user: user),
  );
}

Future<void> downloadIdCard(BuildContext context, WidgetRef ref,
    String idLocation, String fileName) async {
  // Use the cross-platform FileService
  final fileService = ref.read(fileServiceProvider);

  // Pass idLocation directly; FileService handles bucket parsing and defaults
  await fileService.downloadAndOpen(context, idLocation,
      saveAsFileName: fileName.isNotEmpty ? fileName : null);
}
