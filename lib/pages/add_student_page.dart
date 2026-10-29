import 'package:flutter/material.dart';
import '../models/student.dart';
import '../services/storage_service.dart';
import '../widgets/section_dropdown.dart';

// This page is used for BOTH adding and editing a student.
// If a student is given, the page is in edit mode.
class AddStudentPage extends StatefulWidget {
  final Student? student;

  const AddStudentPage({super.key, this.student});

  @override
  State<AddStudentPage> createState() => _AddStudentPageState();
}

class _AddStudentPageState extends State<AddStudentPage> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController idController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController courseController = TextEditingController();

  StorageService storage = StorageService();
  List<String> sections = [];
  String? selectedSection;
  bool isEditing = false;
  bool isLoadingSections = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();

    if (widget.student != null) {
      // Edit mode: fill the form with the current values
      isEditing = true;
      idController.text = widget.student!.id;
      nameController.text = widget.student!.name;
      courseController.text = widget.student!.course;
    } else {
      // Add mode: default course
      courseController.text = 'BS Information Technology';
    }
    loadSections();
  }

  @override
  void dispose() {
    idController.dispose();
    nameController.dispose();
    courseController.dispose();
    super.dispose();
  }

  void showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> loadSections({
    String? preferredSelection,
    bool includeOriginalSection = true,
  }) async {
    try {
      final loadedSections = await storage.loadSections();
      final currentSection = widget.student?.section;
      if (includeOriginalSection &&
          currentSection != null &&
          !loadedSections.contains(currentSection)) {
        loadedSections.add(currentSection);
      }
      if (!mounted) return;
      setState(() {
        sections = loadedSections;
        final nextSelection = preferredSelection ?? selectedSection;
        selectedSection = sections.contains(nextSelection)
            ? nextSelection
            : (includeOriginalSection &&
                    currentSection != null &&
                    sections.contains(currentSection)
                ? currentSection
                : preferredSection(sections));
        isLoadingSections = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        sections = [];
        final currentSection = widget.student?.section;
        if (includeOriginalSection &&
            currentSection != null &&
            !sections.contains(currentSection)) {
          sections.add(currentSection);
        }
        selectedSection = includeOriginalSection
            ? currentSection ?? preferredSection(sections)
            : preferredSection(sections);
        isLoadingSections = false;
      });
      showMessage(
        'Could not load sections. Check your connection and confirm that the section migration was applied.',
      );
    }
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
    final originalSectionRenamed = widget.student?.section != null &&
        result!.renamedSections.containsKey(widget.student!.section);
    await loadSections(
      preferredSelection: nextSelection,
      includeOriginalSection: !originalSectionRenamed,
    );
  }

  String? requiredValidator(
    String? value,
    String message, {
    required int maxLength,
  }) {
    if (value == null || value.trim().isEmpty) {
      return message;
    }
    if (value.trim().length > maxLength) {
      return 'Use $maxLength characters or fewer.';
    }
    return null;
  }

  String? preferredSection(List<String> availableSections) {
    return availableSections.isEmpty ? null : availableSections.first;
  }

  Future<void> saveStudent() async {
    if (isSaving) return;
    if (!formKey.currentState!.validate()) {
      showMessage('Please fill in all required fields.');
      return;
    }
    if (selectedSection == null) {
      showMessage('Please add or select a section.');
      return;
    }

    setState(() => isSaving = true);

    try {
      String id = idController.text.trim();
      String name = nameController.text.trim();
      String course = courseController.text.trim();

      List<Student> students = await storage.loadStudents();

      // Do not allow duplicate Student IDs
      bool idExists = false;
      for (Student s in students) {
        if (s.id == id) {
          bool isSameStudent = isEditing && s.id == widget.student!.id;
          if (!isSameStudent) {
            idExists = true;
          }
        }
      }

      if (idExists) {
        if (!mounted) return;
        showMessage('Student ID already exists.');
        return;
      }

      String message = '';
      final student = Student(
        id: id,
        name: name,
        course: course,
        section: selectedSection!,
      );
      if (isEditing) {
        await storage.saveStudent(student, originalId: widget.student!.id);
        message = 'Student updated successfully.';
      } else {
        await storage.saveStudent(student);
        message = 'Student added successfully.';
      }

      if (!mounted) return;
      Navigator.pop(context, message);
    } catch (_) {
      if (mounted) showMessage('Could not save the student. Please try again.');
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit student' : 'Add student'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth < 380 ? 12.0 : 20.0;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                12,
                horizontalPadding,
                20,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Card(
                    color: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                                  child: Icon(
                                    isEditing
                                        ? Icons.edit_outlined
                                        : Icons.person_add_alt_1,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Student information',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      Text(
                                        isEditing
                                            ? 'Update the details and assigned section.'
                                            : 'Add a student to your class roster.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            TextFormField(
                              controller: idController,
                              maxLength: 64,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Student ID',
                                hintText: 'e.g. 009',
                                prefixIcon: Icon(Icons.badge_outlined),
                                counterText: '',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                return requiredValidator(
                                  value,
                                  'Student ID is required.',
                                  maxLength: 64,
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: nameController,
                              maxLength: 120,
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Student name',
                                hintText: 'e.g. Juan Dela Cruz',
                                prefixIcon: Icon(Icons.person_outline),
                                counterText: '',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                return requiredValidator(
                                  value,
                                  'Student Name is required.',
                                  maxLength: 120,
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: courseController,
                              maxLength: 120,
                              textInputAction: TextInputAction.done,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Course',
                                hintText: 'e.g. BS Information Technology',
                                prefixIcon: Icon(Icons.school_outlined),
                                counterText: '',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                return requiredValidator(
                                  value,
                                  'Course is required.',
                                  maxLength: 120,
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            SectionDropdown(
                              sections: sections,
                              value: selectedSection,
                              enabled: !isLoadingSections && !isSaving,
                              isLoading: isLoadingSections,
                              onChanged: (value) =>
                                  setState(() => selectedSection = value),
                              onManage: manageSections,
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: isSaving || isLoadingSections
                                  ? null
                                  : saveStudent,
                              icon: isSaving
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : Icon(isEditing
                                      ? Icons.save_outlined
                                      : Icons.person_add_alt_1),
                              label: Text(
                                isSaving
                                    ? 'Saving…'
                                    : (isEditing
                                        ? 'Save changes'
                                        : 'Add student'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
