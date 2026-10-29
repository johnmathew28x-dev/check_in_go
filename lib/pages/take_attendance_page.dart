import 'package:flutter/material.dart';
import '../models/student.dart';
import '../models/attendance.dart';
import '../services/storage_service.dart';
import '../utils/helpers.dart';
import '../widgets/section_dropdown.dart';

class TakeAttendancePage extends StatefulWidget {
  const TakeAttendancePage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<TakeAttendancePage> createState() => _TakeAttendancePageState();
}

class _TakeAttendancePageState extends State<TakeAttendancePage> {
  StorageService storage = StorageService();
  final TextEditingController studentSearchController = TextEditingController();

  List<Student> allStudents = [];
  List<Attendance> allAttendance = [];
  List<String> sections = [];

  // studentId -> status (Present / Absent / Tardy)
  Map<String, String> statuses = {};

  DateTime? selectedDate = DateTime.now();
  String? selectedSection;

  bool isLoading = true;
  bool isSavingAttendance = false;
  bool alreadySaved = false;
  String studentSearchQuery = '';

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void dispose() {
    studentSearchController.dispose();
    super.dispose();
  }

  Future<void> loadData({String? sectionToSelect}) async {
    try {
      final loadedStudents = await storage.loadStudents();
      final loadedAttendance = await storage.loadAttendance();
      List<String> loadedSections;
      try {
        loadedSections = await storage.loadSections();
      } catch (_) {
        loadedSections = [];
      }
      final available = <String>{
        ...loadedSections,
        ...loadedStudents.map((student) => student.section),
        ...loadedAttendance.map((record) => record.section),
      }.where((section) => section.isNotEmpty).toList();

      if (!mounted) return;
      setState(() {
        allStudents = loadedStudents;
        allAttendance = loadedAttendance;
        sections = available;
        if (sections.contains(sectionToSelect ?? selectedSection)) {
          selectedSection = sectionToSelect ?? selectedSection;
        } else {
          selectedSection = sections.isEmpty ? null : sections.first;
        }
        loadExistingStatuses();
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoading = false);
      showMessage(
        'Could not load attendance data. Connect to the internet once to cache your roster for offline use.',
      );
    }
  }

  void showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // Students that belong to the selected section
  List<Student> getSectionStudents() {
    List<Student> result = [];
    for (Student student in allStudents) {
      if (student.section == selectedSection) {
        result.add(student);
      }
    }
    return result;
  }

  Future<void> manageSections() async {
    final result = await showSectionManagerDialog(
      context: context,
      storage: storage,
      sections: sections,
    );
    if (result?.changed != true) return;
    final currentSelection = selectedSection;
    final nextSelection = currentSelection == null
        ? null
        : result!.renamedSections[currentSelection] ?? currentSelection;
    await loadData(sectionToSelect: nextSelection);
  }

  List<Student> get visibleSectionStudents {
    final query = studentSearchQuery.trim().toLowerCase();
    final students = getSectionStudents();
    if (query.isEmpty) return students;
    return students.where((student) {
      return student.name.toLowerCase().contains(query) ||
          student.id.toLowerCase().contains(query);
    }).toList();
  }

  void setAllStatuses(String status) {
    setState(() {
      for (final student in getSectionStudents()) {
        statuses[student.id] = status;
      }
    });
  }

  // The default status is Present
  String getStatus(String studentId) {
    return statuses[studentId] ?? 'Present';
  }

  // If attendance was already saved for this date and section,
  // show the saved statuses so the teacher can update them.
  void loadExistingStatuses() {
    statuses.clear();
    alreadySaved = false;

    if (selectedDate == null || selectedSection == null) {
      return;
    }

    String dateText = dateToStorage(selectedDate!);
    for (Attendance record in allAttendance) {
      if (record.date == dateText && record.section == selectedSection) {
        statuses[record.studentId] = record.status;
        alreadySaved = true;
      }
    }
  }

  int countStatus(List<Student> students, String status) {
    int count = 0;
    for (Student student in students) {
      if (getStatus(student.id) == status) {
        count++;
      }
    }
    return count;
  }

  Future<void> pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (!mounted) return;
    if (picked != null) {
      setState(() {
        selectedDate = picked;
        loadExistingStatuses();
      });
    }
  }

  Future<void> saveAttendance() async {
    if (isSavingAttendance) return;
    // Validation
    if (selectedDate == null) {
      showMessage('Please select a date.');
      return;
    }
    if (selectedSection == null) {
      showMessage('Please select a section.');
      return;
    }

    List<Student> sectionStudents = getSectionStudents();

    if (sectionStudents.isEmpty) {
      showMessage('No students found in this section.');
      return;
    }

    for (Student student in sectionStudents) {
      if (!statusList.contains(getStatus(student.id))) {
        showMessage('Please choose a status for every student.');
        return;
      }
    }

    // If attendance already exists, ask the teacher first
    if (alreadySaved) {
      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Attendance Already Recorded'),
            content: const Text(
              'Attendance already recorded for this date. Do you want to update it?',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('Update'),
              ),
            ],
          );
        },
      );

      if (confirm != true) {
        return;
      }
    }

    await doSave(sectionStudents);
  }

  Future<void> doSave(List<Student> sectionStudents) async {
    setState(() => isSavingAttendance = true);
    try {
      final dateText = dateToStorage(selectedDate!);
      final sectionText = selectedSection!;
      final sessionRecords = sectionStudents
          .map((student) => Attendance(
                studentId: student.id,
                studentName: student.name,
                date: dateText,
                section: sectionText,
                status: getStatus(student.id),
              ))
          .toList();

      final synced = await storage.saveAttendanceSession(
        date: dateText,
        section: sectionText,
        records: sessionRecords,
      );

      if (!mounted) return;
      setState(() {
        allAttendance = [
          ...allAttendance.where((record) =>
              record.date != dateText || record.section != sectionText),
          ...sessionRecords,
        ];
        alreadySaved = true;
      });
      showMessage(
        synced
            ? 'Attendance saved and synced.'
            : 'Attendance saved securely on this device. It will sync when you are online.',
      );
    } catch (_) {
      if (!mounted) return;
      showMessage(
        'Could not save attendance. Check your connection and confirm the new attendance migration was applied in Supabase.',
      );
    } finally {
      if (mounted) setState(() => isSavingAttendance = false);
    }
  }

  Widget buildStatusChip(Student student, String status) {
    bool isSelected = getStatus(student.id) == status;

    return ChoiceChip(
      label: Text(status),
      selected: isSelected,
      selectedColor: statusColor(status),
      checkmarkColor: Colors.white,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      labelStyle: TextStyle(
        fontSize: 13,
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: FontWeight.bold,
      ),
      onSelected: (selected) {
        setState(() {
          statuses[student.id] = status;
        });
      },
    );
  }

  Widget buildStudentItem(Student student) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              student.name,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              'Student ID: ${student.id}',
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                buildStatusChip(student, 'Present'),
                buildStatusChip(student, 'Absent'),
                buildStatusChip(student, 'Tardy'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTopCard() {
    String dateLabel = 'Select Date';
    if (selectedDate != null) {
      dateLabel = dateTimeToReadable(selectedDate!);
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
            const Text('Date', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: pickDate,
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  dateLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SectionDropdown(
              sections: sections,
              value: selectedSection,
              onChanged: (value) {
                setState(() {
                  selectedSection = value;
                  loadExistingStatuses();
                });
              },
              onManage: manageSections,
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final stackButtons = constraints.maxWidth < 300;
                final buttonWidth = stackButtons
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 8) / 2;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: buttonWidth,
                      child: OutlinedButton.icon(
                        onPressed: () => setAllStatuses('Present'),
                        icon: const Icon(Icons.done_all),
                        label: const Text('All Present'),
                      ),
                    ),
                    SizedBox(
                      width: buttonWidth,
                      child: OutlinedButton.icon(
                        onPressed: () => setAllStatuses('Absent'),
                        icon: const Icon(Icons.remove_done),
                        label: const Text('All Absent'),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 6),
            TextField(
              controller: studentSearchController,
              onChanged: (value) => setState(() => studentSearchQuery = value),
              decoration: InputDecoration(
                hintText: 'Find a student by name or ID',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: studentSearchQuery.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          studentSearchController.clear();
                          setState(() => studentSearchQuery = '');
                        },
                        icon: const Icon(Icons.clear),
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildAlreadySavedNote() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'Attendance was already saved for this date and section. Saving again will update it.',
        style: TextStyle(fontSize: 13),
      ),
    );
  }

  Widget buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'No students found.',
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            SizedBox(height: 4),
            Text(
              'Add students to this section in the Students page.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildBottomBar(List<Student> sectionStudents) {
    int present = countStatus(sectionStudents, 'Present');
    int absent = countStatus(sectionStudents, 'Absent');
    int tardy = countStatus(sectionStudents, 'Tardy');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
            top: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Present: $present   Absent: $absent   Tardy: $tardy',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isSavingAttendance ? null : saveAttendance,
              icon: isSavingAttendance
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(isSavingAttendance ? 'Saving…' : 'Save Attendance'),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> buildStudentSlivers(
    List<Student> sectionStudents,
    List<Student> visibleStudents,
  ) {
    return [
      if (storage.isUsingOfflineCache)
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Offline or waiting to sync. Attendance is stored encrypted on this device and will retry when online.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      if (alreadySaved) SliverToBoxAdapter(child: buildAlreadySavedNote()),
      if (sectionStudents.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: buildEmptyState(),
        )
      else if (visibleStudents.isEmpty)
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: Text('No students match that search.')),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.all(10),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => buildStudentItem(visibleStudents[index]),
              childCount: visibleStudents.length,
            ),
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    List<Student> sectionStudents = getSectionStudents();
    List<Student> visibleStudents = visibleSectionStudents;

    return Scaffold(
      appBar:
          widget.embedded ? null : AppBar(title: const Text('Take Attendance')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final landscape = constraints.maxWidth >= 640 &&
                      constraints.maxWidth > constraints.maxHeight;
                  final content = Align(
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
                                    width: (constraints.maxWidth * .36)
                                        .clamp(260.0, 360.0)
                                        .toDouble(),
                                    child: SingleChildScrollView(
                                      child: buildTopCard(),
                                    ),
                                  ),
                                  VerticalDivider(
                                    width: 1,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outlineVariant,
                                  ),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Expanded(
                                          child: CustomScrollView(
                                            slivers: buildStudentSlivers(
                                              sectionStudents,
                                              visibleStudents,
                                            ),
                                          ),
                                        ),
                                        buildBottomBar(sectionStudents),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  Expanded(
                                    child: CustomScrollView(
                                      slivers: [
                                        SliverToBoxAdapter(
                                          child: buildTopCard(),
                                        ),
                                        ...buildStudentSlivers(
                                          sectionStudents,
                                          visibleStudents,
                                        ),
                                      ],
                                    ),
                                  ),
                                  buildBottomBar(sectionStudents),
                                ],
                              ),
                      ),
                    ),
                  );
                  return content;
                },
              ),
            ),
    );
  }
}
