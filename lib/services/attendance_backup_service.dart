import 'dart:convert';

import 'package:csv/csv.dart';

import '../models/attendance.dart';

class AttendanceBackupResult {
  const AttendanceBackupResult({
    required this.records,
    required this.issues,
  });

  final List<Attendance> records;
  final List<String> issues;
}

class AttendanceBackupService {
  static const maxCsvBytes = 2 * 1024 * 1024;
  static const maxRows = 10000;

  AttendanceBackupResult parse(String contents) {
    if (utf8.encode(contents).length > maxCsvBytes) {
      throw const FormatException('CSV file must be 2 MB or smaller.');
    }
    final rows = CsvToListConverter(shouldParseNumbers: false)
        .convert(contents.replaceFirst('\uFEFF', ''));
    if (rows.length > maxRows + 1) {
      throw const FormatException('Attendance CSV cannot exceed 10,000 rows.');
    }
    if (rows.isEmpty) {
      return const AttendanceBackupResult(
          records: [], issues: ['The file is empty.']);
    }

    final headers = rows.first.map(_normalizeHeader).toList();
    final dateColumn = _findColumn(headers, ['date', 'attendancedate']);
    final sectionColumn = _findColumn(headers, ['section', 'block']);
    final idColumn = _findColumn(headers, ['studentid', 'id']);
    final nameColumn = _findColumn(headers, ['studentname', 'name']);
    final statusColumn = _findColumn(headers, ['status', 'attendancestatus']);
    if ([dateColumn, sectionColumn, idColumn, nameColumn, statusColumn]
        .contains(null)) {
      return const AttendanceBackupResult(
        records: [],
        issues: [
          'Required columns: attendance_date, section, student_id, student_name, status.',
        ],
      );
    }

    final dateIndex = dateColumn!;
    final sectionIndex = sectionColumn!;
    final idIndex = idColumn!;
    final nameIndex = nameColumn!;
    final statusIndex = statusColumn!;
    final highestColumn = [
      dateIndex,
      sectionIndex,
      idIndex,
      nameIndex,
      statusIndex
    ].reduce((left, right) => left > right ? left : right);
    final records = <Attendance>[];
    final issues = <String>[];
    final seen = <String>{};

    for (var index = 1; index < rows.length; index++) {
      final row = rows[index];
      if (row.every((value) => value.toString().trim().isEmpty)) continue;
      if (row.length <= highestColumn) {
        issues.add('Row ${index + 1}: missing one or more values.');
        continue;
      }

      final date = row[dateIndex].toString().trim();
      final section = row[sectionIndex].toString().trim();
      final studentId = row[idIndex].toString().trim();
      final studentName = row[nameIndex].toString().trim();
      final status = _normalizeStatus(row[statusIndex].toString());
      final parsedDate = DateTime.tryParse(date);
      final validDate = parsedDate != null &&
          date ==
              '${parsedDate.year.toString().padLeft(4, '0')}-'
                  '${parsedDate.month.toString().padLeft(2, '0')}-'
                  '${parsedDate.day.toString().padLeft(2, '0')}';
      if (!validDate ||
          section.isEmpty ||
          section.length > 80 ||
          studentId.isEmpty ||
          studentId.length > 64 ||
          studentName.isEmpty ||
          studentName.length > 120 ||
          status == null) {
        issues.add(
            'Row ${index + 1}: invalid date, section, student, or status.');
        continue;
      }

      final key = jsonEncode([studentId, date, section]);
      if (!seen.add(key)) {
        issues.add('Row ${index + 1}: duplicate attendance row was skipped.');
        continue;
      }
      records.add(Attendance(
        studentId: studentId,
        studentName: studentName,
        date: date,
        section: section,
        status: status,
      ));
    }
    return AttendanceBackupResult(records: records, issues: issues);
  }

  String _normalizeHeader(dynamic value) => value
      .toString()
      .replaceFirst('\uFEFF', '')
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]'), '');

  int? _findColumn(List<String> headers, List<String> names) {
    for (var index = 0; index < headers.length; index++) {
      if (names.contains(headers[index])) return index;
    }
    return null;
  }

  String? _normalizeStatus(String value) {
    switch (value.trim().toLowerCase()) {
      case 'present':
        return 'Present';
      case 'absent':
        return 'Absent';
      case 'tardy':
        return 'Tardy';
      default:
        return null;
    }
  }
}
