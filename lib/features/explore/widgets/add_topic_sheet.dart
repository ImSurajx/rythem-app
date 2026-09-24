import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/database/models/beat_entity.dart';
import '../../../core/database/models/chapter_entity.dart';
import '../../../core/database/repositories/beat_repository.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/glass_button.dart';
import '../../../core/widgets/glass_toast.dart';

/// Frosted liquid glass modal bottom sheet to add or edit a topic (Beat)
/// inside a chapter, adhering strictly to the Mentor-Order Append invariant.
class AddTopicSheet extends StatefulWidget {
  final ChapterEntity chapter;
  final String roadmapId;
  final BeatEntity? existingBeat;
  final BeatRepository? beatRepo;
  final Future<void> Function(BeatEntity beat)? onTopicSaved;

  const AddTopicSheet({
    super.key,
    required this.chapter,
    required this.roadmapId,
    this.existingBeat,
    this.beatRepo,
    this.onTopicSaved,
  });

  static Future<void> show(
    BuildContext context, {
    required ChapterEntity chapter,
    required String roadmapId,
    BeatEntity? existingBeat,
    BeatRepository? beatRepo,
    Future<void> Function(BeatEntity beat)? onTopicSaved,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (ctx) => AddTopicSheet(
        chapter: chapter,
        roadmapId: roadmapId,
        existingBeat: existingBeat,
        beatRepo: beatRepo,
        onTopicSaved: onTopicSaved,
      ),
    );
  }

  @override
  State<AddTopicSheet> createState() => _AddTopicSheetState();
}

class _AddTopicSheetState extends State<AddTopicSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _urlController;
  late double _selectedEffort;
  late int _selectedParts;
  bool _isSaving = false;
  String? _errorMessage;

  final List<double> _effortPresets = [0.5, 1.0, 1.5, 2.0, 3.0];

  @override
  void initState() {
    super.initState();
    final beat = widget.existingBeat;
    _titleController = TextEditingController(text: beat?.title ?? '');
    _urlController = TextEditingController(text: beat?.sourceUrl ?? '');
    _selectedEffort = beat?.effortWeight ?? 1.0;
    _selectedParts = beat?.totalParts ?? 1;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _errorMessage = 'Please enter a topic title');
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() {
      _errorMessage = null;
      _isSaving = true;
    });

    final repo = widget.beatRepo ?? BeatRepository();
    final isEditing = widget.existingBeat != null;
    final now = DateTime.now();

    try {
      BeatEntity finalBeat;
      if (isEditing) {
        final current = widget.existingBeat!;
        final clampedParts = _selectedParts.clamp(1, 20);
        final newCompleted = current.completedParts.clamp(0, clampedParts);
        final isCompleted = newCompleted >= clampedParts;

        finalBeat = current.copyWith(
          title: title,
          sourceUrl: _urlController.text.trim().isEmpty ? null : _urlController.text.trim(),
          effortWeight: _selectedEffort,
          totalParts: clampedParts,
          completedParts: newCompleted,
          isCompleted: isCompleted,
          completedAt: isCompleted ? (current.completedAt ?? now) : null,
          clearCompletedAt: !isCompleted,
          updatedAt: now,
        );
        await repo.updateBeat(finalBeat);
      } else {
        // Compute sequential sort order ensuring placement strictly at the bottom
        final nextSortOrder = await repo.getNextSortOrderForChapter(widget.chapter.id);
        final beatId = 'user_beat_${now.millisecondsSinceEpoch}_${now.microsecond % 1000}';

        finalBeat = BeatEntity(
          id: beatId,
          chapterId: widget.chapter.id,
          roadmapId: widget.roadmapId,
          title: title,
          sourceUrl: _urlController.text.trim().isEmpty ? null : _urlController.text.trim(),
          effortWeight: _selectedEffort,
          sortOrder: nextSortOrder,
          totalParts: _selectedParts.clamp(1, 20),
          completedParts: 0,
          isCompleted: false,
          isMentorExtra: true, // User-created topics are tracked as custom/extra
          createdAt: now,
          updatedAt: now,
        );
        await repo.createBeat(finalBeat);
      }

      if (widget.onTopicSaved != null) {
        await widget.onTopicSaved!(finalBeat);
      }

      if (mounted) {
        Navigator.of(context).pop();
        showGlassToast(
          context,
          isEditing ? 'Topic updated' : 'Added "${finalBeat.title}" to ${widget.chapter.title}',
          icon: isEditing ? Icons.edit_note_rounded : Icons.add_task_rounded,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Failed to save topic: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeColors = isDark ? RythemColors.dark : RythemColors.light;
    final isEditing = widget.existingBeat != null;

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
                            isEditing ? Icons.edit_note_rounded : Icons.playlist_add_rounded,
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
                                isEditing ? 'Edit Topic' : 'Add Custom Topic',
                                style: RythemTypography.titleLarge.copyWith(
                                  color: themeColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Inside chapter: "${widget.chapter.title}"',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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

                    // Error message banner
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

                    // Topic Title Input
                    Text(
                      'TOPIC TITLE',
                      style: RythemTypography.labelSmall.copyWith(
                        color: themeColors.textTertiary,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildTextField(
                      controller: _titleController,
                      hintText: 'e.g. Red-Black Trees Balancing, Memory Layouts',
                      isDark: isDark,
                      themeColors: themeColors,
                      autofocus: !isEditing,
                    ),
                    const SizedBox(height: 16),

                    // Estimated Effort / Duration
                    Text(
                      'ESTIMATED EFFORT (HOURS)',
                      style: RythemTypography.labelSmall.copyWith(
                        color: themeColors.textTertiary,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _effortPresets.map((effort) {
                        final isSelected = (_selectedEffort - effort).abs() < 0.05;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedEffort = effort);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF6366F1).withOpacity(isDark ? 0.35 : 0.2)
                                  : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04)),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF818CF8)
                                    : (isDark ? Colors.white10 : Colors.black12),
                                width: isSelected ? 1.4 : 1.0,
                              ),
                            ),
                            child: Text(
                              effort == 0.5 ? '30m' : '${effort.toStringAsFixed(effort.truncateToDouble() == effort ? 0 : 1)}h',
                              style: RythemTypography.bodySmall.copyWith(
                                color: isSelected
                                    ? (isDark ? Colors.white : const Color(0xFF4338CA))
                                    : themeColors.textSecondary,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Initial Parts Count (Split)
                    Text(
                      'COMPLETE IN PARTS (OPTIONAL)',
                      style: RythemTypography.labelSmall.copyWith(
                        color: themeColors.textTertiary,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [1, 2, 3, 4].map((parts) {
                        final isSelected = _selectedParts == parts;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedParts = parts);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF6366F1).withOpacity(isDark ? 0.35 : 0.2)
                                      : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04)),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF818CF8)
                                        : (isDark ? Colors.white10 : Colors.black12),
                                    width: isSelected ? 1.4 : 1.0,
                                  ),
                                ),
                                child: Text(
                                  parts == 1 ? '1 Part' : '$parts Parts',
                                  style: RythemTypography.bodySmall.copyWith(
                                    color: isSelected
                                        ? (isDark ? Colors.white : const Color(0xFF4338CA))
                                        : themeColors.textSecondary,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Optional Resource Link
                    Text(
                      'RESOURCE URL (OPTIONAL)',
                      style: RythemTypography.labelSmall.copyWith(
                        color: themeColors.textTertiary,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildTextField(
                      controller: _urlController,
                      hintText: 'https://youtube.com/watch?... or https://docs...',
                      isDark: isDark,
                      themeColors: themeColors,
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 22),

                    // Save Glass Button
                    GlassButton(
                      label: isEditing ? 'Save Changes' : 'Append Topic to Chapter',
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required bool isDark,
    required RythemColorTokens themeColors,
    bool autofocus = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
          width: 1.0,
        ),
      ),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        keyboardType: keyboardType,
        style: RythemTypography.bodyMedium.copyWith(
          color: themeColors.textPrimary,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: RythemTypography.bodyMedium.copyWith(
            color: themeColors.textTertiary.withOpacity(0.6),
            fontSize: 13,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}
