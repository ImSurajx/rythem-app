import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/database/models/beat_entity.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';

/// Frosted liquid glass modal bottom sheet allowing learners to schedule spaced revision intervals
/// or keep concepts in their on-demand Revision Shelf without polluting today's mission.
class MarkRevisionSheet extends StatefulWidget {
  final BeatEntity beat;
  final String roadmapTitle;
  final bool isInShelf;
  final int? currentIntervalDays;
  final String? currentNote;
  final Future<void> Function(int? intervalDays, String? note) onSave;
  final VoidCallback? onRemove;

  const MarkRevisionSheet({
    super.key,
    required this.beat,
    required this.roadmapTitle,
    this.isInShelf = false,
    this.currentIntervalDays = 3,
    this.currentNote,
    required this.onSave,
    this.onRemove,
  });

  static Future<void> show(
    BuildContext context, {
    required BeatEntity beat,
    required String roadmapTitle,
    bool isInShelf = false,
    int? currentIntervalDays = 3,
    String? currentNote,
    required Future<void> Function(int? intervalDays, String? note) onSave,
    VoidCallback? onRemove,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MarkRevisionSheet(
        beat: beat,
        roadmapTitle: roadmapTitle,
        isInShelf: isInShelf,
        currentIntervalDays: currentIntervalDays,
        currentNote: currentNote,
        onSave: onSave,
        onRemove: onRemove,
      ),
    );
  }

  @override
  State<MarkRevisionSheet> createState() => _MarkRevisionSheetState();
}

class _MarkRevisionSheetState extends State<MarkRevisionSheet> {
  late int? _selectedIntervalDays;
  late final TextEditingController _noteController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedIntervalDays = widget.currentIntervalDays;
    _noteController = TextEditingController(text: widget.currentNote ?? '');
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    try {
      HapticFeedback.mediumImpact();
      final note = _noteController.text.trim();
      await widget.onSave(_selectedIntervalDays, note.isNotEmpty ? note : null);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _handleRemove() {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
    widget.onRemove?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeColors = isDark ? RythemColors.dark : RythemColors.light;
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: mediaQuery.size.height * 0.85,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xF010141E) : const Color(0xF4FFFFFF),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
              border: Border.all(
                color: isDark ? themeColors.glassBorder : const Color(0x18000000),
                width: 0.9,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.45 : 0.12),
                  blurRadius: 28,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4.5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),

                  // Header Badge & Title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(isDark ? 0.22 : 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF6366F1).withOpacity(0.4),
                            width: 0.8,
                          ),
                        ),
                        child: const Icon(
                          Icons.bookmark_add_rounded,
                          size: 18,
                          color: Color(0xFF818CF8),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SPACED REVISION SHELF',
                              style: RythemTypography.labelSmall.copyWith(
                                color: const Color(0xFF818CF8),
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.isInShelf ? 'Update Revision Interval' : 'Mark for Spaced Revision',
                              style: RythemTypography.titleMedium.copyWith(
                                color: themeColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Beat title box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? themeColors.glassBorder : const Color(0x10000000),
                        width: 0.7,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.beat.title,
                          style: RythemTypography.bodyMedium.copyWith(
                            color: themeColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.roadmapTitle,
                          style: RythemTypography.caption.copyWith(
                            color: themeColors.textTertiary,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'WHEN DO YOU WANT TO REVISIT THIS?',
                    style: RythemTypography.labelSmall.copyWith(
                      color: themeColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      fontSize: 10.5,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Option 1: 3 Days
                  _buildIntervalOption(
                    title: 'In 3 Days',
                    subtitle: 'Initial reinforcement • Lock in new neural pathways',
                    icon: Icons.bolt_rounded,
                    accentColor: const Color(0xFF38BDF8),
                    isSelected: _selectedIntervalDays == 3,
                    onTap: () => setState(() => _selectedIntervalDays = 3),
                    isDark: isDark,
                    themeColors: themeColors,
                  ),

                  const SizedBox(height: 8),

                  // Option 2: 1 Week
                  _buildIntervalOption(
                    title: 'In 1 Week',
                    subtitle: 'Spaced repetition • Weekly retention block',
                    icon: Icons.date_range_rounded,
                    accentColor: const Color(0xFFA855F7),
                    isSelected: _selectedIntervalDays == 7,
                    onTap: () => setState(() => _selectedIntervalDays = 7),
                    isDark: isDark,
                    themeColors: themeColors,
                  ),

                  const SizedBox(height: 8),

                  // Option 3: Keep in Shelf (Indefinite / On demand)
                  _buildIntervalOption(
                    title: 'Keep in Shelf (On Demand)',
                    subtitle: 'Guilt-free review • Practice anytime without deadlines',
                    icon: Icons.inventory_2_outlined,
                    accentColor: const Color(0xFF10B981),
                    isSelected: _selectedIntervalDays == null,
                    onTap: () => setState(() => _selectedIntervalDays = null),
                    isDark: isDark,
                    themeColors: themeColors,
                  ),

                  const SizedBox(height: 16),

                  // Personal Friction Note
                  Text(
                    'PERSONAL FRICTION NOTE (OPTIONAL)',
                    style: RythemTypography.labelSmall.copyWith(
                      color: themeColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      fontSize: 10.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _noteController,
                    maxLines: 2,
                    style: RythemTypography.bodySmall.copyWith(
                      color: themeColors.textPrimary,
                      fontSize: 12.5,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. Remember to review edge case formulas...',
                      hintStyle: RythemTypography.bodySmall.copyWith(
                        color: themeColors.textTertiary,
                        fontSize: 12,
                      ),
                      filled: true,
                      fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? themeColors.glassBorder : const Color(0x18000000),
                          width: 0.8,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? themeColors.glassBorder : const Color(0x18000000),
                          width: 0.8,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF6366F1),
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Actions
                  Row(
                    children: [
                      if (widget.isInShelf && widget.onRemove != null) ...[
                        OutlinedButton.icon(
                          onPressed: _isSaving ? null : _handleRemove,
                          icon: const Icon(Icons.bookmark_remove_outlined, size: 16, color: Color(0xFFEF4444)),
                          label: Text(
                            'Unshelf',
                            style: RythemTypography.button.copyWith(
                              color: const Color(0xFFEF4444),
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            side: BorderSide(
                              color: const Color(0xFFEF4444).withOpacity(0.4),
                              width: 1,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _handleSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      widget.isInShelf ? Icons.check_circle_outline_rounded : Icons.bookmark_add_rounded,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      widget.isInShelf ? 'Update Schedule' : 'Add to Revision Shelf',
                                      style: RythemTypography.button.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntervalOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    required RythemThemeColors themeColors,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withOpacity(isDark ? 0.20 : 0.12)
              : (isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? accentColor.withOpacity(isDark ? 0.75 : 0.6)
                : (isDark ? themeColors.glassBorder : const Color(0x14000000)),
            width: isSelected ? 1.4 : 0.8,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(isDark ? 0.25 : 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: accentColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: RythemTypography.bodyMedium.copyWith(
                      color: isSelected ? accentColor : themeColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 1.5),
                  Text(
                    subtitle,
                    style: RythemTypography.caption.copyWith(
                      color: themeColors.textTertiary,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? accentColor : Colors.transparent,
                border: Border.all(
                  color: isSelected ? accentColor : themeColors.textTertiary.withOpacity(0.4),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
