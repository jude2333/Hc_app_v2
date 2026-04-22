import 'dart:html' as html;
import 'dart:typed_data';

/// Web implementation — triggers browser file download
Future<void> saveExcelFile(List<int> bytes, String filename) async {
  final blob = html.Blob(
    [Uint8List.fromList(bytes)],
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..style.display = 'none';
  html.document.body!.children.add(anchor);
  anchor.click();
  html.document.body!.children.remove(anchor);
  html.Url.revokeObjectUrl(url);
}
