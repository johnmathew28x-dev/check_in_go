import 'package:csv/csv.dart';

import '../models/student.dart';

class RosterImportResult {
  final List<Student> students;
  final int duplicateCount;
  final List<String> issues;

  const RosterImportResult({
    required this.students,
    required this.duplicateCount,
    required this.issues,
  });
}

class RosterImportService {
  static const maxCsvBytes = 2 * 1024 * 1024;
  static const maxRosterRows = 10000;

  RosterImportResult parse(String csvText, Set<String> existingIds) {
    if (csvText.length > maxCsvBytes) {
      throw const FormatException('CSV file must be 2 MB or smaller.');
    }
    final rows = CsvToListConverter(shouldParseNumbers: false).convert(csvText);
    if (rows.length > maxRosterRows + 1) {
      throw const FormatException('CSV roster cannot exceed 10,000 students.');
    }
    if (rows.isEmpty) {
      return const RosterImportResult(
        students: [],
        duplicateCount: 0,
        issues: ['The CSV file is empty.'],
      );
    }

    final headers = rows.first.map(_normalizeHeader).toList();
    final idColumn = _findColumn(headers, ['id', 'studentid', 'studentnumber']);
    final nameColumn =
        _findColumn(headers, ['name', 'studentname', 'fullname']);
    final courseColumn = _findColumn(headers, ['course', 'program']);
    final sectionColumn = _findColumn(headers, ['section', 'classsection']);

    if (idColumn == null ||
        nameColumn == null ||
        courseColumn == null ||
        sectionColumn == null) {
      return const RosterImportResult(
        students: [],
        duplicateCount: 0,
        issues: [
          'Required columns: student_id, name, course, section. '
              'Column order does not matter.',
        ],
      );
    }

    final acceptedIds = {...existingIds};
    final students = <Student>[];
    final issues = <String>[];
    var duplicateCount = 0;
    final requiredColumn = [idColumn, nameColumn, courseColumn, sectionColumn]
        .reduce((left, right) => left > right ? left : right);

    for (var index = 1; index < rows.length; index++) {
      final row = rows[index];
      if (row.every((value) => value.toString().trim().isEmpty)) continue;

      if (row.length <= requiredColumn) {
        issues.add('Row ${index + 1}: missing one or more values.');
        continue;
      }

      final id = row[idColumn].toString().trim();
      final name = row[nameColumn].toString().trim();
      final course = row[courseColumn].toString().trim();
      final section = row[sectionColumn].toString().trim();
      if (id.isEmpty || name.isEmpty || course.isEmpty || section.isEmpty) {
        issues.add(
            'Row ${index + 1}: ID, name, course, and section are required.');
        continue;
      }

      if (id.length > 64 ||
          name.length > 120 ||
          course.length > 120 ||
          section.length > 80) {
        issues.add('Row ${index + 1}: one or more values are too long.');
        continue;
      }

      if (!acceptedIds.add(id)) {
        duplicateCount++;
        continue;
      }

      students.add(Student(
        id: id,
        name: name,
        course: course,
        section: section,
      ));
    }

    return RosterImportResult(
      students: students,
      duplicateCount: duplicateCount,
      issues: issues,
    );
  }

  String _normalizeHeader(dynamic value) => value
      .toString()
      .replaceFirst('\uFEFF', '')
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]'), '');

  int? _findColumn(List<String> headers, List<String> aliases) {
    for (var index = 0; index < headers.length; index++) {
      if (aliases.contains(headers[index])) return index;
    }
    return null;
  }
}
