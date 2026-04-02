/// Stub for non-web platforms.
/// These functions are only used on web; on mobile they are never called.

String createBlobUrl(List<int> bytes) {
  throw UnsupportedError('createBlobUrl is only supported on web');
}

void registerIFrameFactory(String viewType, String url) {
  throw UnsupportedError('registerIFrameFactory is only supported on web');
}
