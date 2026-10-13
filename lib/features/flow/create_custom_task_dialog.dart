import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rythem_app/core/database/models/roadmap_entity.dart';
import 'package:rythem_app/core/theme/colors.dart';
import 'package:rythem_app/core/theme/typography.dart';
import 'package:rythem_app/core/widgets/glass_button.dart';
import 'package:rythem_app/core/widgets/smooth_dialog.dart';

/// Modal dialog allowing users to create a custom study/revision task
/// for a specific roadmap tracker.
class CreateCustomTaskDialog extends StatefulWidget {
  final RoadmapEntity roadmap;
  final void Function(String title, double effortWeight, String? sourceUrl, String category) onTaskCreated;

  const CreateCustomTaskDialog({
    super.key,
    required this.roadmap,
    required this.onTaskCreated,
  });

  static Future<void> show(
    BuildContext context, {
    required RoadmapEntity roadmap,
    required void Function(String title, double effortWeight, String? sourceUrl, String category) onTaskCreated,
  }) {
    return showSmoothDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (ctx) => CreateCustomTaskDialog(
        roadmap: roadmap,
        onTaskCreated: onTaskCreated,
      ),
    );
  }

  @override
  State<CreateCustomTaskDialog> createState() => _CreateCustomTaskDialogState();
}

class _CreateCustomTaskDialogState extends State<CreateCustomTaskDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _urlController;
  late final TextEditingController _effortController;

  String _selectedCategory = 'Revision';
  final List<String> _presetCategories = [
    'Revision',
    'Practice',
    'Deep Dive',
    'Side Project',
    'General',
  ];

  double _selectedEffort = 1.0;
  final List<double> _presetEfforts = [0.5, 1.0, 1.5, 2.0, 3.0];
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _urlController = TextEditingController();
    _effortController = TextEditingController(text: '1.0');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    _effortController.dispose();
    super.dispose();
  }

  void _selectPresetEffort(double value) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedEffort = value;
      _effortController.text = value.toStringAsFixed(1);
    });
  }

  void _onCustomEffortChanged(String value) {
    final parsed = double.tryParse(value.trim());
    if (parsed != null && parsed > 0) {
      setState(() {
        _selectedEffort = parsed;
      });
    }
  }

  void _handleSave() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() {
        _errorText = 'Please enter a task title';
      });
      return;
    }

    final parsedEffort = double.tryParse(_effortController.text.trim()) ?? _selectedEffort;
    final finalEffort = parsedEffort > 0 ? parsedEffort : 1.0;
    final url = _urlController.text.trim();

    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
    widget.onTaskCreated(
      title,
      finalEffort,
      url.isNotEmpty ? url : null,
      _selectedCategory,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeColors = isDark ? RythemColors.dark : RythemColors.light;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 22),
        constraints: const BoxConstraints(maxWidth: 440),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.55) : Colors.black.withOpacity(0.12),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xE8161616) : const Color(0xF4FFFFFF),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? themeColors.glassBorder : const Color(0x28000000),
                  width: 1.0,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0x25FFFFFF) : const Color(0x12000000),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.add_task_rounded,
                                  size: 18,
                                  color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Create Custom Task',
                                    style: RythemTypography.titleMedium.copyWith(
                                      color: themeColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    widget.roadmap.title,
                                    style: RythemTypography.labelSmall.copyWith(
                                      color: themeColors.textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: themeColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Category Selector
                      Text(
                        'CATEGORY',
                        style: RythemTypography.labelSmall.copyWith(
                          color: themeColors.textTertiary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 7),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _presetCategories.map((cat) {
                            final isSelected = _selectedCategory == cat;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: InkWell(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _selectedCategory = cat);
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? (isDark
                                            ? const Color(0xFFF59E0B).withOpacity(0.2)
                                            : const Color(0xFFD97706).withOpacity(0.12))
                                        : (isDark
                                            ? Colors.white.withOpacity(0.04)
                                            : Colors.black.withOpacity(0.03)),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected
                                          ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706))
                                          : (isDark ? themeColors.glassBorder : const Color(0x18000000)),
                                      width: isSelected ? 1.2 : 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        cat == 'Revision'
                                            ? Icons.repeat_rounded
                                            : cat == 'Practice'
                                                ? Icons.code_rounded
                                                : cat == 'Deep Dive'
                                                    ? Icons.menu_book_rounded
                                                    : cat == 'Side Project'
                                                        ? Icons.rocket_launch_rounded
                                                        : Icons.task_alt_rounded,
                                        size: 11,
                                        color: isSelected
                                            ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706))
                                            : themeColors.textSecondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        cat,
                                        style: RythemTypography.labelSmall.copyWith(
                                          color: isSelected
                                              ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706))
                                              : themeColors.textSecondary,
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Input 1: Task Title
                      Text(
                        'TASK TITLE / TOPIC',
                        style: RythemTypography.labelSmall.copyWith(
                          color: themeColors.textTertiary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _titleController,
                        autofocus: true,
                        style: RythemTypography.bodyMedium.copyWith(
                          color: themeColors.textPrimary,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: 'e.g. Revision: Dynamic Programming, solve 5 problems',
                          hintStyle: RythemTypography.bodySmall.copyWith(
                            color: themeColors.textTertiary.withOpacity(0.6),
                            fontSize: 12,
                          ),
                          errorText: _errorText,
                          filled: true,
                          fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark ? themeColors.glassBorder : const Color(0x18000000),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark ? themeColors.glassBorder : const Color(0x18000000),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: themeColors.textPrimary.withOpacity(0.7),
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        onChanged: (_) {
                          if (_errorText != null) {
                            setState(() => _errorText = null);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Input 2: Effort Points
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'EFFORT POINTS',
                            style: RythemTypography.labelSmall.copyWith(
                              color: themeColors.textTertiary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Text(
                            '⚡ ${_selectedEffort.toStringAsFixed(1)} pts',
                            style: RythemTypography.labelSmall.copyWith(
                              color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Preset chips row + custom field
                      Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _presetEfforts.map((effort) {
                                  final isSelected = (_selectedEffort - effort).abs() < 0.05;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: InkWell(
                                      onTap: () => _selectPresetEffort(effort),
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? (isDark
                                                  ? Colors.white.withOpacity(0.18)
                                                  : Colors.black.withOpacity(0.12))
                                              : (isDark
                                                  ? Colors.white.withOpacity(0.04)
                                                  : Colors.black.withOpacity(0.03)),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isSelected
                                                ? (isDark ? Colors.white : Colors.black)
                                                : (isDark ? themeColors.glassBorder : const Color(0x18000000)),
                                            width: isSelected ? 1.2 : 0.8,
                                          ),
                                        ),
                                        child: Text(
                                          '${effort.toStringAsFixed(1)} pts',
                                          style: RythemTypography.labelSmall.copyWith(
                                            color: isSelected ? themeColors.textPrimary : themeColors.textSecondary,
                                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 64,
                            height: 34,
                            child: TextField(
                              controller: _effortController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textAlign: TextAlign.center,
                              style: RythemTypography.labelSmall.copyWith(
                                color: themeColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                              decoration: InputDecoration(
                                hintText: 'pts',
                                filled: true,
                                fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                                contentPadding: EdgeInsets.zero,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: isDark ? themeColors.glassBorder : const Color(0x18000000),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: isDark ? themeColors.glassBorder : const Color(0x18000000),
                                  ),
                                ),
                              ),
                              onChanged: _onCustomEffortChanged,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Input 3: Optional Resource URL
                      Text(
                        'RESOURCE LINK (OPTIONAL)',
                        style: RythemTypography.labelSmall.copyWith(
                          color: themeColors.textTertiary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _urlController,
                        style: RythemTypography.bodyMedium.copyWith(
                          color: themeColors.textPrimary,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: 'https://...',
                          hintStyle: RythemTypography.bodySmall.copyWith(
                            color: themeColors.textTertiary.withOpacity(0.6),
                            fontSize: 12,
                          ),
                          filled: true,
                          fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark ? themeColors.glassBorder : const Color(0x18000000),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark ? themeColors.glassBorder : const Color(0x18000000),
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Explanatory glass pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? themeColors.glassBorder : const Color(0x10000000),
                            width: 0.6,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 13,
                              color: themeColors.textTertiary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'When completed, this task permanently appends to your tracker right after your last completed topic and counts toward your daily study streak.',
                                style: RythemTypography.bodySmall.copyWith(
                                  color: themeColors.textTertiary,
                                  fontSize: 10.5,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Actions
                      Row(
                        children: [
                          Expanded(
                            child: GlassButton(
                              label: 'Cancel',
                              variant: GlassButtonVariant.secondary,
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GlassButton(
                              label: 'Add to Focus 🎯',
                              variant: GlassButtonVariant.primary,
                              onPressed: _handleSave,
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
        ),
      ),
    );
  }
}
