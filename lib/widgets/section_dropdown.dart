import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/storage_service.dart';

class SectionDropdown extends StatelessWidget {
  const SectionDropdown({
    super.key,
    required this.sections,
    required this.value,
    required this.onChanged,
    required this.onManage,
    this.enabled = true,
    this.isLoading = false,
  });

  final List<String> sections;
  final String? value;
  final ValueChanged<String?> onChanged;
  final VoidCallback onManage;
  final bool enabled;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final selectedValue = sections.contains(value) ? value : null;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Section',
        prefixIcon: Icon(Icons.groups_outlined, color: colors.primary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 4,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedValue,
                hint: Text(
                  isLoading
                      ? 'Loading sections…'
                      : sections.isEmpty
                          ? 'Add a section'
                          : 'Choose a section',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                isExpanded: true,
                isDense: true,
                itemHeight: 48,
                menuMaxHeight: 320,
                borderRadius: BorderRadius.circular(12),
                dropdownColor: colors.surface,
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: colors.onSurfaceVariant,
                ),
                style: textTheme.bodyLarge?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                selectedItemBuilder: (context) => sections
                    .map(
                      (section) => Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          section,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                items: sections
                    .map(
                      (section) => DropdownMenuItem<String>(
                        value: section,
                        child: Row(
                          children: [
                            Icon(
                              Icons.groups_outlined,
                              size: 18,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                section,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: enabled && !isLoading && sections.isNotEmpty
                    ? onChanged
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 2),
          TextButton.icon(
            onPressed: enabled ? onManage : null,
            icon: const Icon(Icons.tune_rounded, size: 17),
            label: const Text('Manage'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 44),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SectionManagerResult {
  const SectionManagerResult({
    required this.changed,
    this.renamedSections = const {},
  });

  final bool changed;
  final Map<String, String> renamedSections;
}

Future<SectionManagerResult?> showSectionManagerDialog({
  required BuildContext context,
  required StorageService storage,
  required List<String> sections,
}) {
  return showDialog<SectionManagerResult>(
    context: context,
    builder: (context) => _SectionManagerDialog(
      storage: storage,
      sections: sections,
    ),
  );
}

class _SectionManagerDialog extends StatefulWidget {
  const _SectionManagerDialog({
    required this.storage,
    required this.sections,
  });

  final StorageService storage;
  final List<String> sections;

  @override
  State<_SectionManagerDialog> createState() => _SectionManagerDialogState();
}

class _SectionManagerDialogState extends State<_SectionManagerDialog> {
  final TextEditingController controller = TextEditingController();
  final TextEditingController editController = TextEditingController();
  late List<String> sections = List<String>.from(widget.sections);
  String? editingSection;
  final Map<String, String> renamedSections = {};
  bool isBusy = false;
  bool changed = false;
  String? errorMessage;
  String? successMessage;

  String describeSupabaseError(PostgrestException error, String action) {
    if (error.code == '42P01' || error.code == 'PGRST205') {
      return 'Section management is not set up in this Supabase project. '
          'Run 20261023010000_section_management.sql after the other migrations.';
    }
    if (error.code == '42501') {
      if (action == 'rename') {
        return 'Supabase is not allowing section renaming yet. Run '
            '20261028010000_rename_sections.sql in the CheckInGo SQL Editor, '
            'then try again.';
      }
      return 'Supabase denied this change. Check that you are signed in and '
          'the sections security policy is installed.';
    }
    if (error.code == '23505') {
      return 'That section already exists.';
    }
    return 'Could not $action the section (${error.code}): ${error.message}';
  }

  @override
  void dispose() {
    controller.dispose();
    editController.dispose();
    super.dispose();
  }

  Future<void> addSection() async {
    if (isBusy || editingSection != null) return;
    setState(() {
      isBusy = true;
      errorMessage = null;
      successMessage = null;
    });

    try {
      final name = controller.text.trim().toUpperCase();
      await widget.storage.addSection(name);
      if (!mounted) return;
      setState(() {
        sections = [...sections, name];
        controller.clear();
        changed = true;
        successMessage = '$name added successfully.';
      });
    } on FormatException catch (error) {
      if (mounted) setState(() => errorMessage = error.message);
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() => errorMessage = describeSupabaseError(error, 'add'));
      }
    } on StateError catch (error) {
      if (mounted) {
        setState(() => errorMessage = error.message.toString());
      }
    } catch (error) {
      if (mounted) {
        setState(() => errorMessage = 'Could not add section: $error');
      }
    } finally {
      if (mounted) setState(() => isBusy = false);
    }
  }

  Future<void> removeSection(String section) async {
    if (isBusy || editingSection != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove section?'),
        content: Text('Remove $section from the section list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      isBusy = true;
      errorMessage = null;
      successMessage = null;
    });
    try {
      await widget.storage.removeSection(section);
      if (!mounted) return;
      setState(() {
        sections.remove(section);
        changed = true;
        successMessage = '$section removed successfully.';
      });
    } on StateError catch (error) {
      if (mounted) {
        setState(() => errorMessage = error.message.toString());
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() => errorMessage = describeSupabaseError(error, 'remove'));
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          errorMessage = 'Could not remove section: $error';
        });
      }
    } finally {
      if (mounted) setState(() => isBusy = false);
    }
  }

  void beginEditSection(String section) {
    if (isBusy) return;
    setState(() {
      editingSection = section;
      editController.text = section;
      errorMessage = null;
      successMessage = null;
    });
  }

  void cancelEditSection() {
    if (editingSection == null) return;
    setState(() {
      editingSection = null;
      editController.clear();
      errorMessage = null;
      successMessage = null;
    });
  }

  Future<void> saveSectionName() async {
    final section = editingSection;
    if (isBusy || section == null) return;
    final newName = editController.text.trim().toUpperCase();
    if (newName == section) {
      cancelEditSection();
      return;
    }
    setState(() {
      isBusy = true;
      errorMessage = null;
      successMessage = null;
    });
    try {
      await widget.storage.renameSection(section, newName);
      if (!mounted) return;
      setState(() {
        sections = sections
            .map((current) => current == section ? newName : current)
            .toList();
        var originalName = section;
        for (final entry in renamedSections.entries) {
          if (entry.value == section) {
            originalName = entry.key;
            break;
          }
        }
        renamedSections.remove(section);
        if (originalName != newName) {
          renamedSections[originalName] = newName;
        }
        editingSection = null;
        editController.clear();
        changed = true;
        successMessage = '$section renamed to $newName.';
      });
    } on FormatException catch (error) {
      if (mounted) setState(() => errorMessage = error.message);
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() => errorMessage = describeSupabaseError(error, 'rename'));
      }
    } on StateError catch (error) {
      if (mounted) setState(() => errorMessage = error.message.toString());
    } catch (error) {
      if (mounted) {
        setState(() => errorMessage = 'Could not rename section: $error');
      }
    } finally {
      if (mounted) setState(() => isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final colors = Theme.of(context).colorScheme;
    final availableHeight =
        media.size.height - media.padding.vertical - media.viewInsets.bottom;
    final contentHeight =
        (availableHeight - 230).clamp(120.0, 380.0).toDouble();

    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Manage sections'),
          const SizedBox(height: 3),
          Text(
            'Add or rename your class blocks.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: contentHeight,
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: !isBusy && editingSection == null,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    maxLength: 80,
                    onSubmitted: (_) => addSection(),
                    decoration: const InputDecoration(
                      labelText: 'New section',
                      hintText: 'e.g. BSIT-4A',
                      counterText: '',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: IconButton.filled(
                    tooltip: 'Add section',
                    onPressed:
                        isBusy || editingSection != null ? null : addSection,
                    icon: const Icon(Icons.add),
                  ),
                ),
              ],
            ),
            if (errorMessage != null || successMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: errorMessage == null
                      ? colors.primaryContainer.withValues(alpha: 0.65)
                      : colors.errorContainer.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      errorMessage == null
                          ? Icons.check_circle_outline
                          : Icons.error_outline,
                      size: 18,
                      color: errorMessage == null
                          ? colors.onPrimaryContainer
                          : colors.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        errorMessage ?? successMessage!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: errorMessage == null
                                  ? colors.onPrimaryContainer
                                  : colors.onErrorContainer,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Your sections',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${sections.length}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: sections.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.groups_outlined,
                              size: 34,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No sections yet',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Add a section above to get started.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: colors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: sections.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final section = sections[index];
                        return ListTile(
                          dense: true,
                          minVerticalPadding: 4,
                          horizontalTitleGap: 8,
                          minLeadingWidth: 24,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          tileColor: editingSection == section
                              ? colors.primaryContainer.withValues(alpha: 0.55)
                              : colors.surfaceContainerHighest
                                  .withValues(alpha: 0.38),
                          leading: editingSection == section
                              ? null
                              : Icon(
                                  Icons.groups_outlined,
                                  size: 20,
                                  color: colors.onSurfaceVariant,
                                ),
                          title: editingSection == section
                              ? TextField(
                                  controller: editController,
                                  autofocus: true,
                                  enabled: !isBusy,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  textInputAction: TextInputAction.done,
                                  maxLength: 80,
                                  onSubmitted: (_) => saveSectionName(),
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  decoration: const InputDecoration(
                                    hintText: 'Section name',
                                    counterText: '',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 10,
                                    ),
                                  ),
                                )
                              : Text(
                                  section,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                          trailing: editingSection == section
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Cancel rename',
                                      onPressed:
                                          isBusy ? null : cancelEditSection,
                                      icon: const Icon(Icons.close),
                                    ),
                                    IconButton(
                                      tooltip: 'Save section name',
                                      onPressed:
                                          isBusy ? null : saveSectionName,
                                      icon: const Icon(Icons.check),
                                    ),
                                  ],
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Rename $section',
                                      onPressed:
                                          isBusy || editingSection != null
                                              ? null
                                              : () => beginEditSection(section),
                                      icon: const Icon(Icons.edit_outlined),
                                    ),
                                    IconButton(
                                      tooltip: 'Remove $section',
                                      onPressed:
                                          isBusy || editingSection != null
                                              ? null
                                              : () => removeSection(section),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isBusy
              ? null
              : () => Navigator.pop(
                    context,
                    SectionManagerResult(
                      changed: changed,
                      renamedSections: Map.unmodifiable(renamedSections),
                    ),
                  ),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
