import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Mobile implementation for CSV export using file sharing
Future<void> exportCsvPlatform(String content, String fileName) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/$fileName');
  await file.writeAsString(content);
  
  await Share.shareXFiles(
    [XFile(file.path)],
    text: 'Exported data',
  );
}
