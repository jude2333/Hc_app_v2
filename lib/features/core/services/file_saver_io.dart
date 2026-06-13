import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter/foundation.dart';

class FileSaver {
  static Future<void> saveAndLaunch(List<int> bytes, String fileName) async {
    Directory? directory;

    if (Platform.isAndroid) {
      directory = await getExternalStorageDirectory();
    } else if (Platform.isIOS || Platform.isMacOS) {
      directory = await getApplicationDocumentsDirectory();
    } else {
      // Windows/Linux
      directory = await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
    }

    // Fallback if directory is null
    directory ??= await getApplicationDocumentsDirectory();

    final filePath = '${directory.path}${Platform.pathSeparator}$fileName';
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    debugPrint('File saved to $filePath');

    // Open the file
    final result = await OpenFilex.open(filePath);
    if (result.type != ResultType.done) {
      debugPrint('Error opening file: ${result.message}');
    }
  }
}
