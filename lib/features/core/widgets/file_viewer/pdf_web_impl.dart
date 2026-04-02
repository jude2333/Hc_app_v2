// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui;

String createBlobUrl(List<int> bytes) {
  final htmlContent = bytes is String ? bytes : String.fromCharCodes(bytes);
  final blob = html.Blob([htmlContent], 'text/html');
  return html.Url.createObjectUrlFromBlob(blob);
}

void registerIFrameFactory(String viewType, String url) {
  ui.platformViewRegistry.registerViewFactory(
    viewType,
    (int viewId) => html.IFrameElement()
      ..src = url
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..setAttribute('allow', 'fullscreen')
      ..setAttribute('sandbox', 'allow-scripts allow-same-origin allow-popups'),
  );
}
