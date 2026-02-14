/// Stub implementation for FileSaver.
/// This file is used when neither dart:html nor dart:io are available (should not happen in standard Flutter).
class FileSaver {
  static Future<void> saveAndLaunch(List<int> bytes, String fileName) async {
    throw UnsupportedError('Platform not supported');
  }
}
