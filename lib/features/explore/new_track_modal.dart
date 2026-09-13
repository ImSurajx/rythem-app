import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rythem_app/core/theme/colors.dart';
import 'package:rythem_app/core/theme/typography.dart';
import 'package:rythem_app/core/widgets/glass_button.dart';

/// Modal to create a new curriculum track adhering to `docs/design.md` §4
class NewTrackModal extends StatefulWidget {
  final Future<void> Function({
    required String title,
    required String category,
    required DateTime targetDate,
    String? resourceUrl,
    String? syllabusText,
  }) onCreateTrack;

  const NewTrackModal({
    super.key,
    required this.onCreateTrack,
  });

  static Future<void> show(
    BuildContext context, {
    required Future<void> Function({
      required String title,
      required String category,
      required DateTime targetDate,
      String? resourceUrl,
      String? syllabusText,
    }) onCreateTrack,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NewTrackModal(onCreateTrack: onCreateTrack),
    );
  }

  @override
  State<NewTrackModal> createState() => _NewTrackModalState();
}

class _NewTrackModalState extends State<NewTrackModal> {
  final _titleController = TextEditingController();
  final _resourceController = TextEditingController();
  final _syllabusController = TextEditingController();
  bool _showSyllabusInput = false;
  String _selectedCategory = 'Engineering';
  DateTime _targetDate = DateTime.now().add(const Duration(days: 14));
  bool _isLoading = false;

  late List<String> _categories;

  @override
  void initState() {
    super.initState();
    _categories = [
      'Engineering',
      'System Design',
      'Mathematics',
      'Computer Science',
      'General',
    ];
  }

  Future<void> _importFileFromStorage() async {
    HapticFeedback.lightImpact();
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['json', 'txt', 'md'],
      );

      if (file != null) {
        String? content;
        try {
          final bytes = await file.readAsBytes();
          if (bytes.isNotEmpty) {
            content = utf8.decode(bytes);
          }
        } catch (_) {}

        if ((content == null || content.isEmpty) && file.path != null) {
          content = await File(file.path!).readAsString();
        }

        if (content != null && content.trim().isNotEmpty) {
          setState(() {
            _showSyllabusInput = true;
            _syllabusController.text = content!;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Loaded "${file.name}" from storage'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error picking syllabus file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file: $e')),
        );
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    HapticFeedback.lightImpact();
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      setState(() {
        _showSyllabusInput = true;
        _syllabusController.text = data.text!;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pasted syllabus from clipboard'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Clipboard is empty'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showAddCustomCategoryDialog() {
    final catController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final themeColors = isDark ? RythemColors.dark : RythemColors.light;

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            'New Category',
            style: RythemTypography.titleMedium.copyWith(
              color: themeColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: TextField(
            controller: catController,
            autofocus: true,
            style: TextStyle(color: themeColors.textPrimary, fontSize: 13.5),
            decoration: InputDecoration(
              hintText: 'e.g. Deep Learning, Mobile, Finance',
              hintStyle: TextStyle(color: themeColors.textTertiary, fontSize: 12),
              filled: true,
              fillColor: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: themeColors.glassBorder),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: themeColors.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                final text = catController.text.trim();
                if (text.isNotEmpty) {
                  Navigator.pop(ctx);
                  setState(() {
                    if (!_categories.contains(text)) {
                      _categories.add(text);
                    }
                    _selectedCategory = text;
                  });
                }
              },
              child: Text(
                'Add',
                style: TextStyle(color: themeColors.textPrimary, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }


  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a track title')),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      final resourceUrl = _resourceController.text.trim().isNotEmpty
          ? _resourceController.text.trim()
          : null;
      final syllabusText = _syllabusController.text.trim().isNotEmpty
          ? _syllabusController.text.trim()
          : null;

      await widget.onCreateTrack(
        title: title,
        category: _selectedCategory,
        targetDate: _targetDate,
        resourceUrl: resourceUrl,
        syllabusText: syllabusText,
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating track: $e')),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.white,
              onPrimary: Colors.black,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _targetDate = picked);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _resourceController.dispose();
    _syllabusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeColors = isDark ? RythemColors.dark : RythemColors.light;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xF2161616) : const Color(0xF5FFFFFF),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: isDark ? themeColors.glassBorder : const Color(0x20000000),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'CREATE NEW TRACK',
                    style: RythemTypography.labelSmall.copyWith(
                      color: themeColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 20, color: themeColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Title input
              Text(
                'Track Title',
                style: RythemTypography.labelSmall.copyWith(
                  color: themeColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _titleController,
                autofocus: true,
                style: TextStyle(color: themeColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'e.g. Distributed Systems Masterclass',
                  hintStyle: TextStyle(color: themeColors.textTertiary, fontSize: 13),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.black.withOpacity(0.04),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: themeColors.glassBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: themeColors.glassBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark ? themeColors.glassBorderHighlight : Colors.black87,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Category selector
              Text(
                'Category',
                style: RythemTypography.labelSmall.copyWith(
                  color: themeColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._categories.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedCategory = cat);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.09))
                              : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? (isDark ? themeColors.glassBorderHighlight : Colors.black87)
                                : (isDark ? themeColors.glassBorder : const Color(0x14000000)),
                            width: isSelected ? 1.2 : 0.8,
                          ),
                        ),
                        child: Text(
                          cat,
                          style: RythemTypography.labelSmall.copyWith(
                            color: isSelected ? themeColors.textPrimary : themeColors.textTertiary,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    );
                  }),
                  // + Custom category button
                  GestureDetector(
                    onTap: _showAddCustomCategoryDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? themeColors.glassBorder : const Color(0x18000000),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 14, color: themeColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            'Custom',
                            style: RythemTypography.labelSmall.copyWith(
                              color: themeColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Target Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Target Completion Date',
                        style: RythemTypography.labelSmall.copyWith(
                          color: themeColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_targetDate.year}-${_targetDate.month.toString().padLeft(2, '0')}-${_targetDate.day.toString().padLeft(2, '0')}',
                        style: RythemTypography.titleSmall.copyWith(
                          color: themeColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.calendar_month_outlined,
                        color: themeColors.textPrimary, size: 20),
                    onPressed: _pickDate,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Optional Resource URL
              Text(
                'Resource URL (Optional Playlist / Video)',
                style: RythemTypography.labelSmall.copyWith(
                  color: themeColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _resourceController,
                style: TextStyle(color: themeColors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'https://youtube.com/playlist?list=...',
                  hintStyle: TextStyle(color: themeColors.textTertiary, fontSize: 12),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.black.withOpacity(0.04),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: themeColors.glassBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: themeColors.glassBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark ? themeColors.glassBorderHighlight : Colors.black87,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Syllabus Import Section
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _showSyllabusInput = !_showSyllabusInput);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.025),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _showSyllabusInput
                          ? (isDark ? themeColors.glassBorderHighlight : Colors.black54)
                          : (isDark ? themeColors.glassBorder : const Color(0x14000000)),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.playlist_add_check_rounded,
                            size: 18,
                            color: themeColors.textPrimary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Import / Paste Syllabus (Optional)',
                            style: RythemTypography.labelSmall.copyWith(
                              color: themeColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                      Icon(
                        _showSyllabusInput
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: themeColors.textTertiary,
                      ),
                    ],
                  ),
                ),
              ),

              if (_showSyllabusInput) ...[
                const SizedBox(height: 8),
                Text(
                  'Import JSON / TXT from storage, paste clipboard text, or enter topics manually.',
                  style: RythemTypography.bodySmall.copyWith(
                    color: themeColors.textTertiary,
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _importFileFromStorage,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: themeColors.glassBorder),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.folder_open_rounded, size: 16, color: themeColors.textPrimary),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Import File',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: themeColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: _pasteFromClipboard,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: themeColors.glassBorder),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.content_paste_rounded, size: 16, color: themeColors.textPrimary),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Paste Text',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: themeColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _syllabusController,
                  maxLines: 6,
                  minLines: 3,
                  style: TextStyle(color: themeColors.textPrimary, fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: 'e.g.\nModule 1: Foundations\n- Arrays and Strings\n- Two Sum\n- Sliding Window\nModule 2: Search\n- Binary Search',
                    hintStyle: TextStyle(color: themeColors.textTertiary, fontSize: 11),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.03),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: themeColors.glassBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: themeColors.glassBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? themeColors.glassBorderHighlight : Colors.black87,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: GlassButton(
                  label: _isLoading ? 'Creating Track...' : 'Create Track',
                  icon: Icons.add_rounded,
                  onPressed: _isLoading ? () {} : _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
