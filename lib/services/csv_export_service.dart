import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';

class CsvExportService {
  Future<bool> saveCsv({
    required String fileName,
    required List<List<Object?>> rows,
  }) async {
    final csv = const ListToCsvConverter().convert(rows);
    final path = await FilePicker.saveFile(
      dialogTitle: 'Save CSV backup',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      bytes: Uint8List.fromList(utf8.encode('\uFEFF$csv')),
    );
    return path != null;
  }
}
