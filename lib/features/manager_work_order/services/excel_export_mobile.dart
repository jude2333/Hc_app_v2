import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Mobile implementation — saves to temp and opens share sheet
Future<void> saveExcelFile(List<int> bytes, String filename) async {
  final dir = await getTemporaryDirectory();
  final filePath = '${dir.path}/$filename';
  final file = File(filePath);
  await file.writeAsBytes(bytes, flush: true);

  await Share.shareXFiles(
    [XFile(filePath)],
    subject: 'Technician Analytics Report',
  );
}
