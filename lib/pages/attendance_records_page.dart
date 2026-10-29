import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/attendance.dart';
import '../services/attendance_backup_service.dart';
import '../services/csv_export_service.dart';
import '../services/storage_service.dart';
import '../utils/helpers.dart';
import '../widgets/attendance_card.dart';
import '../widgets/section_dropdown.dart';

class AttendanceRecordsPage extends StatefulWidget {
  const AttendanceRecordsPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AttendanceRecordsPage> createState() => _AttendanceRecordsPageState();
}

class _AttendanceRecordsPageState extends State<AttendanceRecordsPage> {
  StorageService storage = StorageService();
  List<Attendance> allAttendance = [];
  bool isLoading = true;
  bool isBackupBusy = false;

  // Filters
  DateTime? filterDate;
  String filterSection = 'All';
  List<String> filterSections = [];

  @override
  void initState() {
    super.initState();
    filterSections.add('All');
    loadRecords();
  }

  Future<void> loadRecords() async {
    try {
      final loaded = await storage.loadAttendance();
      List<String> loadedSections;
      try {
        loadedSections = await storage.loadSections();
      } catch (_) {
        loadedSections = [];
      }
      final names = <String>{
        ...loadedSections,
        ...loaded.map((record) => record.section),
      }.where((section) => section.isNotEmpty).toList();
      if (!mounted) return;
      setState(() {
        allAttendance = loaded;
        filterSections = ['All', ...names];
        if (!filterSections.contains(filterSection)) filterSection = 'All';
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoading = false);
      showMessage(
          'Could not load records. Check your connection or sign in again.');
    }
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> exportAttendanceCsv() async {
    if (isBackupBusy) return;
    final records = getFilteredRecords();
    if (records.isEmpty) {
      showMessage('There are no attendance records to export.');
      return;
    }
    setState(() => isBackupBusy = true);
    try {
      final date = DateTime.now().toIso8601String().split('T').first;
      final saved = await CsvExportService().saveCsv(
        fileName: 'checkingo_attendance_$date.csv',
        rows: [
          [
            'attendance_date',
            'section',
            'student_id',
            'student_name',
            'status'
          ],
          ...records.map((record) => <Object?>[
                record.date,
                record.section,
                record.studentId,
                record.studentName,
                record.status,
              ]),
        ],
      );
      if (saved) showMessage('Attendance CSV backup saved.');
    } catch (_) {
      showMessage('Could not export attendance. Please try again.');
    } finally {
      if (mounted) setState(() => isBackupBusy = false);
    }
  }

  Future<void> restoreAttendanceCsv() async {
    if (isBackupBusy) return;
    setState(() => isBackupBusy = true);
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        withReadStream: true,
      );
      if (picked == null || picked.files.isEmpty || !mounted) return;
      final file = picked.files.first;
      if (file.size > AttendanceBackupService.maxCsvBytes) {
        throw const FormatException(
          'Choose a readable CSV file no larger than 2 MB.',
        );
      }
      final stream = file.readStream;
      if (stream == null) {
        throw const FormatException('The selected CSV could not be read.');
      }
      final contents = BytesBuilder(copy: false);
      var byteCount = 0;
      await for (final chunk in stream) {
        byteCount += chunk.length;
        if (byteCount > AttendanceBackupService.maxCsvBytes) {
          throw const FormatException('CSV file must be 2 MB or smaller.');
        }
        contents.add(chunk);
      }
      final parsed =
          AttendanceBackupService().parse(utf8.decode(contents.takeBytes()));
      final rosterIds =
          (await storage.loadStudents()).map((student) => student.id).toSet();
      if (!mounted) return;
      final validRecords = parsed.records
          .where((record) => rosterIds.contains(record.studentId))
          .toList();
      final unknownStudentCount = parsed.records.length - validRecords.length;
      if (validRecords.isEmpty) {
        showMessage(parsed.issues.isEmpty
            ? unknownStudentCount > 0
                ? 'No rows matched students in your roster.'
                : 'The CSV has no attendance rows.'
            : parsed.issues.take(2).join(' '));
        return;
      }

      final preview = [
        'Attendance rows ready to restore: ${validRecords.length}',
        if (parsed.issues.isNotEmpty || unknownStudentCount > 0)
          'Rows skipped: ${parsed.issues.length + unknownStudentCount}',
        ...parsed.issues.take(3),
        if (unknownStudentCount > 0)
          '$unknownStudentCount rows use student IDs not in your roster.',
        if (parsed.issues.length > 3)
          '…and ${parsed.issues.length - 3} more issues.',
        'Existing matching rows will be updated; other attendance stays as it is.',
      ].join('\n');
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Restore attendance backup?'),
          content: SingleChildScrollView(child: Text(preview)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Restore'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      final count = await storage.importAttendanceRecords(validRecords);
      await loadRecords();
      if (!mounted) return;
      showMessage(storage.isUsingOfflineCache
          ? 'Restored $count rows to encrypted offline storage. They will sync when online.'
          : 'Restored $count attendance rows.');
    } on FormatException catch (error) {
      showMessage(error.message);
    } catch (_) {
      showMessage(
        'Could not restore the CSV. Confirm the students exist in your roster and the attendance migration is installed.',
      );
    } finally {
      if (mounted) setState(() => isBackupBusy = false);
    }
  }

  Future<void> manageSections() async {
    final result = await showSectionManagerDialog(
      context: context,
      storage: storage,
      sections: filterSections.where((section) => section != 'All').toList(),
    );
    if (result?.changed != true) return;
    final renamedSelection = result!.renamedSections[filterSection];
    if (renamedSelection != null && mounted) {
      setState(() => filterSection = renamedSelection);
    }
    await loadRecords();
  }

  Future<void> pickFilterDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: filterDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (!mounted) return;
    if (picked != null) {
      setState(() {
        filterDate = picked;
      });
    }
  }

  // Apply the date and section filters
  List<Attendance> getFilteredRecords() {
    List<Attendance> result = [];

    for (Attendance record in allAttendance) {
      bool dateOk = true;
      if (filterDate != null) {
        dateOk = record.date == dateToStorage(filterDate!);
      }

      bool sectionOk = true;
      if (filterSection != 'All') {
        sectionOk = record.section == filterSection;
      }

      if (dateOk && sectionOk) {
        result.add(record);
      }
    }
    return result;
  }

  // Group the records by date + section (newest date first)
  List<Widget> buildRecordCards(List<Attendance> records) {
    Map<String, List<Attendance>> groups = {};

    for (Attendance record in records) {
      String key = '${record.date}|${record.section}';
      if (groups[key] == null) {
        groups[key] = [];
      }
      groups[key]!.add(record);
    }

    List<String> keys = groups.keys.toList();
    keys.sort((a, b) => b.compareTo(a));

    List<Widget> cards = [];
    for (String key in keys) {
      List<String> parts = key.split('|');
      cards.add(AttendanceCard(
        date: parts[0],
        section: parts[1],
        records: groups[key]!,
      ));
    }
    return cards;
  }

  Widget buildFilterCard() {
    String dateLabel = 'All Dates';
    if (filterDate != null) {
      dateLabel = dateTimeToReadable(filterDate!);
    }

    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filter', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: pickFilterDate,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      dateLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (filterDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: 'Clear date',
                    onPressed: () {
                      setState(() {
                        filterDate = null;
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SectionDropdown(
              sections: filterSections,
              value: filterSection,
              onChanged: (value) {
                if (value != null) setState(() => filterSection = value);
              },
              onManage: manageSections,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton.icon(
                  onPressed: isBackupBusy ? null : exportAttendanceCsv,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Export CSV'),
                ),
                OutlinedButton.icon(
                  onPressed: isBackupBusy ? null : restoreAttendanceCsv,
                  icon: const Icon(Icons.restore_outlined),
                  label: const Text('Restore CSV'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Attendance> filtered = getFilteredRecords();
    List<Widget> cards = buildRecordCards(filtered);

    Widget listArea;
    if (filtered.isEmpty) {
      listArea = const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.list_alt, size: 48, color: Colors.grey),
              SizedBox(height: 8),
              Text(
                'No attendance records found.',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            ],
          ),
        ),
      );
    } else {
      listArea = ListView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        children: cards,
      );
    }

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(title: const Text('Attendance Records')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final landscape = constraints.maxWidth >= 640 &&
                      constraints.maxWidth > constraints.maxHeight;
                  return Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1280),
                      child: SizedBox(
                        width: double.infinity,
                        height: constraints.maxHeight,
                        child: landscape
                            ? Row(
                                children: [
                                  SizedBox(
                                    width: (constraints.maxWidth * .32)
                                        .clamp(250.0, 330.0)
                                        .toDouble(),
                                    child: SingleChildScrollView(
                                      child: buildFilterCard(),
                                    ),
                                  ),
                                  VerticalDivider(
                                    width: 1,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outlineVariant,
                                  ),
                                  Expanded(child: listArea),
                                ],
                              )
                            : Column(
                                children: [
                                  buildFilterCard(),
                                  Expanded(child: listArea),
                                ],
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
