import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/student.dart';
import '../services/csv_export_service.dart';
import '../services/roster_import_service.dart';
import '../services/storage_service.dart';
import '../widgets/student_card.dart';
import 'add_student_page.dart';
import 'student_attendance_page.dart';

class StudentsPage extends StatefulWidget {
  const StudentsPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  final StorageService storage = StorageService();
  final TextEditingController searchController = TextEditingController();
  List<Student> students = [];
  bool isLoading = true;
  bool isImporting = false;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    loadStudents();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadStudents() async {
    try {
      final loaded = await storage.loadStudents();
      if (!mounted) return;
      setState(() {
        students = loaded;
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoading = false);
      showMessage(
          'Could not load students. Check your connection and try again.');
    }
  }

  List<Student> get filteredStudents {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return students;
    return students.where((student) {
      return student.name.toLowerCase().contains(query) ||
          student.id.toLowerCase().contains(query) ||
          student.course.toLowerCase().contains(query) ||
          student.section.toLowerCase().contains(query);
    }).toList();
  }

  void showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> openAddStudent() async {
    final message = await Navigator.push<String>(
      context,
      MaterialPageRoute<String>(builder: (context) => const AddStudentPage()),
    );
    await loadStudents();
    if (!mounted) return;
    if (message != null) showMessage(message);
  }

  Future<void> openEditStudent(Student student) async {
    final message = await Navigator.push<String>(
      context,
      MaterialPageRoute<String>(
        builder: (context) => AddStudentPage(student: student),
      ),
    );
    await loadStudents();
    if (!mounted) return;
    if (message != null) showMessage(message);
  }

  Future<void> exportRoster() async {
    if (students.isEmpty) {
      showMessage('There are no students to export.');
      return;
    }
    try {
      final date = DateTime.now().toIso8601String().split('T').first;
      final saved = await CsvExportService().saveCsv(
        fileName: 'checkingo_roster_$date.csv',
        rows: [
          ['student_id', 'name', 'course', 'section'],
          ...students.map((student) => <Object?>[
                student.id,
                student.name,
                student.course,
                student.section,
              ]),
        ],
      );
      if (saved) showMessage('Roster CSV backup saved.');
    } catch (_) {
      showMessage('Could not export the roster. Please try again.');
    }
  }

  void openStudentAttendance(Student student) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentAttendancePage(student: student),
      ),
    );
  }

  void confirmDelete(Student student) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Student'),
          content: const Text(
            'Are you sure you want to delete this student?\n\n'
            'Their attendance records will also be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                deleteStudent(student);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> deleteStudent(Student student) async {
    final remaining = students.where((s) => s.id != student.id).toList();
    setState(() => students = remaining);

    try {
      await storage.deleteStudent(student.id);
      showMessage('Student deleted successfully.');
    } catch (_) {
      await loadStudents();
      showMessage('Could not delete the student. Please try again.');
    }
  }

  Future<void> importRoster() async {
    if (isImporting) return;
    setState(() => isImporting = true);

    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withReadStream: true,
      );
      if (picked == null || picked.files.isEmpty) return;

      final selectedFile = picked.files.first;
      if (selectedFile.size > RosterImportService.maxCsvBytes) {
        throw const FormatException('CSV file must be 2 MB or smaller.');
      }
      final stream = selectedFile.readStream;
      if (stream == null) {
        throw const FormatException('The selected CSV could not be read.');
      }

      final contents = BytesBuilder(copy: false);
      var byteCount = 0;
      await for (final chunk in stream) {
        byteCount += chunk.length;
        if (byteCount > RosterImportService.maxCsvBytes) {
          throw const FormatException('CSV file must be 2 MB or smaller.');
        }
        contents.add(chunk);
      }
      final csvText =
          utf8.decode(contents.takeBytes()).replaceFirst('\uFEFF', '');
      if (byteCount == 0) {
        throw const FormatException('The selected CSV is empty.');
      }
      final result = RosterImportService().parse(
        csvText,
        students.map((student) => student.id).toSet(),
      );

      if (!mounted) return;
      if (result.students.isEmpty) {
        await showImportReport(result, canImport: false);
        return;
      }

      final confirmed = await showImportReport(result, canImport: true);
      if (confirmed != true || !mounted) return;

      final latestStudents = await storage.loadStudents();
      final latestIds = latestStudents.map((student) => student.id).toSet();
      final newStudents = result.students
          .where((student) => !latestIds.contains(student.id))
          .toList();
      if (newStudents.isEmpty) {
        await loadStudents();
        showMessage('Those student IDs are already in the roster.');
        return;
      }

      await storage.saveStudents([...latestStudents, ...newStudents]);
      await loadStudents();
      if (!mounted) return;
      showMessage('Imported ${newStudents.length} students.');
    } on FormatException catch (error) {
      showMessage(error.message);
    } catch (_) {
      showMessage(
          'Could not import the roster. Check the CSV file and try again.');
    } finally {
      if (mounted) setState(() => isImporting = false);
    }
  }

  Future<bool?> showImportReport(
    RosterImportResult result, {
    required bool canImport,
  }) {
    final details = <String>[
      if (canImport) 'Ready to add: ${result.students.length}',
      if (result.duplicateCount > 0)
        'Skipped duplicate IDs: ${result.duplicateCount}',
      if (result.issues.isNotEmpty)
        'Rows with problems: ${result.issues.length}',
      ...result.issues.take(4),
      if (result.issues.length > 4)
        '…and ${result.issues.length - 4} more row issues.',
    ];

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title:
            Text(canImport ? 'Import roster?' : 'Roster could not be imported'),
        content: SingleChildScrollView(child: Text(details.join('\n'))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(canImport ? 'Cancel' : 'Close'),
          ),
          if (canImport)
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Import'),
            ),
        ],
      ),
    );
  }

  Widget buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline,
              size: 48,
              color: colorScheme.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 8),
            Text(
              'No students found.',
              style: TextStyle(fontSize: 16, color: colorScheme.onSurface),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: openAddStudent,
              icon: const Icon(Icons.add),
              label: const Text('Add Student'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: isImporting ? null : importRoster,
              icon: const Icon(Icons.upload_file),
              label: const Text('Import CSV roster'),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: TextField(
        controller: searchController,
        onChanged: (value) => setState(() => searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Search name, student ID, course, or section',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: searchQuery.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    searchController.clear();
                    setState(() => searchQuery = '');
                  },
                  icon: const Icon(Icons.clear),
                ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget buildRosterHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Class roster', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 3),
        Text(
          'Search, view, or update your students.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
    final count = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        '${students.length} ${students.length == 1 ? 'student' : 'students'}',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Export roster CSV',
          onPressed: students.isEmpty ? null : exportRoster,
          icon: const Icon(Icons.download_outlined),
        ),
        IconButton(
          tooltip: 'Import CSV roster',
          onPressed: isImporting ? null : importRoster,
          icon: isImporting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload_file),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 440;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 2),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: title),
                        count,
                      ],
                    ),
                    if (widget.embedded)
                      Align(alignment: Alignment.centerRight, child: actions),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: title),
                    count,
                    if (widget.embedded) actions,
                  ],
                ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleStudents = filteredStudents;
    Widget body;

    if (isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (students.isEmpty) {
      body = buildEmptyState();
    } else {
      body = Column(
        children: [
          buildRosterHeader(),
          buildSearchField(),
          Expanded(
            child: visibleStudents.isEmpty
                ? const Center(child: Text('No students match that search.'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 84),
                    itemCount: visibleStudents.length,
                    itemBuilder: (context, index) {
                      final student = visibleStudents[index];
                      return StudentCard(
                        student: student,
                        onView: () => openStudentAttendance(student),
                        onEdit: () => openEditStudent(student),
                        onDelete: () => confirmDelete(student),
                      );
                    },
                  ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('Students'),
              actions: [
                IconButton(
                  tooltip: 'Export roster CSV',
                  onPressed: students.isEmpty ? null : exportRoster,
                  icon: const Icon(Icons.download_outlined),
                ),
                IconButton(
                  tooltip: 'Import CSV roster',
                  onPressed: isImporting ? null : importRoster,
                  icon: isImporting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file),
                ),
              ],
            ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth =
                constraints.maxWidth > 900 ? 900.0 : constraints.maxWidth;
            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: contentWidth,
                height: constraints.maxHeight,
                child: body,
              ),
            );
          },
        ),
      ),
      floatingActionButton: students.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: openAddStudent,
              icon: const Icon(Icons.add),
              label: const Text('Add Student'),
            ),
    );
  }
}
