import 'package:csv/csv.dart';

// Conditional imports for platform-specific code
import 'excel_export_stub.dart'
    if (dart.library.html) 'excel_export_web.dart'
    if (dart.library.io) 'excel_export_mobile.dart';

/// Service class for exporting data to CSV/Excel format
/// Works on both web and mobile platforms
class ExcelExportService {
  static final ExcelExportService instance = ExcelExportService._();
  ExcelExportService._();

  /// Converts data to CSV format and downloads/shares
  /// [headers] - List of column headers
  /// [rows] - List of rows, each row is a list of cell values
  /// [fileName] - Name of the file to download (without extension)
  Future<void> exportToCsv({
    required List<String> headers,
    required List<List<dynamic>> rows,
    required String fileName,
  }) async {
    // Add headers as first row
    final List<List<dynamic>> csvData = [headers, ...rows];
    
    // Convert to CSV string
    final String csvString = const ListToCsvConverter().convert(csvData);
    
    // Use platform-specific export
    await exportCsvPlatform(csvString, '$fileName.csv');
  }

  /// Helper to format date for export
  String formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  /// Helper to format currency
  String formatCurrency(double? value) {
    if (value == null) return '';
    return '₹${value.toStringAsFixed(2)}';
  }
}
