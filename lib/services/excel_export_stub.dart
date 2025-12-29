/// Stub implementation for unsupported platforms
Future<void> exportCsvPlatform(String content, String fileName) async {
  throw UnsupportedError('CSV export is not supported on this platform');
}
