import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/database/models/chapter_entity.dart';
import '../../../core/database/repositories/chapter_repository.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_toast.dart';

/// Frosted liquid glass modal bottom sheet to create or edit a custom chapter
/// in a curriculum roadmap, strictly appending to the bottom in mentor order.
class AddChapterSheet extends StatefulWidget {
  final String roadmapId;
  final ChapterEntity? existingChapter;
  final ChapterRepository? chapterRepo;
  final Future<void> Function(ChapterEntity chapter)? onChapterSaved;

  const AddChapterSheet({
    super.key,
    required this.roadmapId,
    this.existingChapter,
    this.chapterRepo,
    this.onChapterSaved,
  });

  static Future<void> show(
    BuildContext context, {
    required String roadmapId,
    ChapterEntity? existingChapter,
    ChapterRepository? chapterRepo,
    Future<void> Function(ChapterEntity chapter)? onChapterSaved,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (ctx) => AddChapterSheet(
        roadmapId: roadmapId,
        existingChapter: existingChapter,
        chapterRepo: chapterRepo,
        onChapterSaved: onChapterSaved,
      ),
    );
  }

  @override
  State<AddChapterSheet> createState() => _AddChapterSheetState();
}

class _AddChapterSheetState extends State<AddChapterSheet> {
  late final TextEditingController _titleController;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existingChapter?.title ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _errorMessage = 'Please enter a chapter title');
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() {
      _errorMessage = null;
      _isSaving = true;
    });

    final repo = widget.chapterRepo ?? ChapterRepository();
    final isEditing = widget.existingChapter != null;
    final now = DateTime.now();

    try {
      ChapterEntity finalChapter;
      if (isEditing) {
        finalChapter = widget.existingChapter!.copyWith(
          title: title,
          updatedAt: now,
        );
        await repo.updateChapter(finalChapter);
      } else {
        final nextSortOrder = await repo.getNextSortOrder(widget.roadmapId);
        final chapterId = 'user_ch_${now.millisecondsSinceEpoch}_${now.microsecond % 1000}';

        finalChapter = ChapterEntity(
          id: chapterId,
          roadmapId: widget.roadmapId,
          title: title,
          sortOrder: nextSortOrder,
          createdAt: now,
          updatedAt: now,
        );
        await repo.createChapter(finalChapter);
      }

      if (widget.onChapterSaved != null) {
        await widget.onChapterSaved!(finalChapter);
      }

      if (mounted) {
        Navigator.of(context).pop();
        showGlassToast(
          context,
          isEditing ? 'Chapter renamed' : 'Added "${finalChapter.title}" to track',
          icon: isEditing ? Icons.edit_rounded : Icons.create_new_folder_rounded,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Failed to save chapter: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeColors = isDark ? RythemColors.dark : RythemColors.light;
    final isEditing = widget.existingChapter != null;

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xEE161822)
                  : const Color(0xEEF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.12)
                    : Colors.black.withOpacity(0.08),
                width: 1.0,
              ),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Drag Handle
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(isDark ? 0.2 : 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isEditing ? Icons.drive_file_rename_outline_rounded : Icons.create_new_folder_rounded,
                            size: 22,
                            color: const Color(0xFF818CF8),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEditing ? 'Edit Chapter' : 'Add Custom Chapter',
                                style: RythemTypography.titleLarge.copyWith(
                                  color: themeColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isEditing
                                    ? 'Rename this chapter'
                                    : 'Appends a new chapter module at the end of this tracker',
                                style: RythemTypography.bodySmall.copyWith(
                                  color: themeColors.textTertiary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: themeColors.textTertiary, size: 20),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Error banner
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 16, color: Colors.redAccent),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: RythemTypography.bodySmall.copyWith(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Chapter Title Input
                    Text(
                      'CHAPTER TITLE',
                      style: RythemTypography.labelSmall.copyWith(
                        color: themeColors.textTertiary,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
                          width: 1.0,
                        ),
                      ),
                      child: TextField(
                        controller: _titleController,
                        autofocus: true,
                        style: RythemTypography.bodyMedium.copyWith(
                          color: themeColors.textPrimary,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: 'e.g. Chapter 4: Distributed Caching & Consensus',
                          hintStyle: RythemTypography.bodyMedium.copyWith(
                            color: themeColors.textTertiary.withOpacity(0.6),
                            fontSize: 13,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Save Button
                    GlassButton(
                      label: isEditing ? 'Update Chapter' : 'Append Chapter to Tracker',
                      icon: isEditing ? Icons.check_rounded : Icons.add_rounded,
                      variant: GlassButtonVariant.primary,
                      isLoading: _isSaving,
                      onPressed: _isSaving ? null : _handleSave,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
