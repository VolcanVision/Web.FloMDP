import 'dart:convert';
import 'package:universal_html/html.dart' as html;

/// Web implementation for CSV export
Future<void> exportCsvPlatform(String content, String fileName) async {
  final bytes = utf8.encode(content);
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  
  html.Url.revokeObjectUrl(url);
}
