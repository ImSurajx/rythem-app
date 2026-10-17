import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rythem_app/core/database/models/roadmap_entity.dart';
import 'package:rythem_app/core/database/repositories/app_settings_repository.dart';
import 'package:rythem_app/core/theme/colors.dart';
import 'package:rythem_app/core/theme/typography.dart';
import 'package:rythem_app/core/widgets/glass_button.dart';
import 'package:rythem_app/core/widgets/smooth_dialog.dart';

/// Modal dialog allowing users to create a custom study/revision/project task
/// for a specific roadmap tracker or the Open Lab tracker.
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
  final _appSettingsRepo = AppSettingsRepository();
  late final TextEditingController _titleController;
  late final TextEditingController _urlController;
  late final TextEditingController _hoursController;
  late final TextEditingController _newCategoryController;

  List<String> _categories = List.from(AppSettingsRepository.defaultStarterCategories);
  String _selectedCategory = 'Revision';
  bool _isAddingCategory = false;

  // Selected duration in hours: default 1.0 hr (60m -> 6.0 pts)
  double _selectedHours = 1.0;
  final List<double> _presetHours = [0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0];
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _urlController = TextEditingController();
    _hoursController = TextEditingController(text: '1.0');
    _newCategoryController = TextEditingController();
    _loadSavedCategories();
  }

  Future<void> _loadSavedCategories() async {
    try {
      final saved = await _appSettingsRepo.getCustomTaskCategories();
      if (mounted && saved.isNotEmpty) {
        setState(() {
          _categories = saved;
          if (!_categories.contains(_selectedCategory)) {
            _selectedCategory = _categories.first;
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    _hoursController.dispose();
    _newCategoryController.dispose();
    super.dispose();
  }

  String _formatDurationReadable(double hours) {
    final totalMinutes = (hours * 60).round();
    if (totalMinutes < 60) {
      return '$totalMinutes min';
    }
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return m > 0 ? '${h}h ${m}m' : '$h hr${h > 1 ? 's' : ''}';
  }

  String _formatPresetChip(double hours) {
    final totalMinutes = (hours * 60).round();
    if (totalMinutes < 60) {
      return '${totalMinutes}m';
    }
    final h = totalMinutes / 60.0;
    if (h == h.roundToDouble()) {
      return '${h.toInt()}h';
    }
    return '${h.toStringAsFixed(1)}h';
  }

  void _selectPresetHours(double value) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedHours = value;
      _hoursController.text = value.toStringAsFixed(value == value.roundToDouble() ? 1 : 2);
    });
  }

  void _onCustomHoursChanged(String value) {
    final parsed = double.tryParse(value.trim());
    if (parsed != null && parsed > 0) {
      setState(() {
        _selectedHours = parsed;
      });
    }
  }

  Future<void> _handleAddCustomCategory() async {
    final newCat = _newCategoryController.text.trim();
    if (newCat.isNotEmpty) {
      HapticFeedback.selectionClick();
      setState(() {
        if (!_categories.any((c) => c.toLowerCase() == newCat.toLowerCase())) {
          _categories.add(newCat);
        }
        _selectedCategory = newCat;
        _isAddingCategory = false;
        _newCategoryController.clear();
      });
      try {
        await _appSettingsRepo.saveCustomTaskCategory(newCat);
      } catch (_) {}
    } else {
      setState(() {
        _isAddingCategory = false;
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

    final parsedHours = double.tryParse(_hoursController.text.trim()) ?? _selectedHours;
    final finalHours = parsedHours > 0 ? parsedHours : 1.0;
    // 10 min = 1 effort point -> 1 hour = 6 effort points
    final calculatedEffort = (finalHours * 6.0).clamp(0.5, 60.0);
    final url = _urlController.text.trim();

    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
    widget.onTaskCreated(
      title,
      calculatedEffort,
      url.isNotEmpty ? url : null,
      _selectedCategory,
    );

    unawaited(_appSettingsRepo.saveCustomTaskCategory(_selectedCategory));
  }

  IconData _getCategoryIcon(String cat) {
    final lower = cat.toLowerCase();
    if (lower.contains('revision') || lower.contains('review')) return Icons.repeat_rounded;
    if (lower.contains('practice') || lower.contains('exercise') || lower.contains('problem')) return Icons.code_rounded;
    if (lower.contains('read') || lower.contains('book') || lower.contains('paper')) return Icons.menu_book_rounded;
    if (lower.contains('project') || lower.contains('build') || lower.contains('app')) return Icons.rocket_launch_rounded;
    if (lower.contains('deep') || lower.contains('research')) return Icons.biotech_rounded;
    if (lower.contains('open') || lower.contains('source')) return Icons.public_rounded;
    return Icons.bookmark_border_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeColors = isDark ? RythemColors.dark : RythemColors.light;
    final calculatedEffort = (_selectedHours * 6.0).clamp(0.5, 60.0);

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
                                  widget.roadmap.isOpenLab ? Icons.science_rounded : Icons.add_task_rounded,
                                  size: 18,
                                  color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.roadmap.isOpenLab ? 'Log Task' : 'Custom Task',
                                    style: RythemTypography.titleMedium.copyWith(
                                      color: themeColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    widget.roadmap.isOpenLab ? 'Open Lab' : widget.roadmap.title,
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

                      // Category Selector with Dynamic Memory & Custom Creator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'CATEGORY',
                            style: RythemTypography.labelSmall.copyWith(
                              color: themeColors.textTertiary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          if (!_isAddingCategory)
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _isAddingCategory = true);
                              },
                              child: Text(
                                '+ Add Category',
                                style: RythemTypography.labelSmall.copyWith(
                                  color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 7),

                      // If adding custom category, show inline textfield
                      if (_isAddingCategory) ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _newCategoryController,
                                autofocus: true,
                                style: RythemTypography.bodySmall.copyWith(
                                  color: themeColors.textPrimary,
                                  fontSize: 12,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'e.g. Anatomy, Torts, Open Source, Calculus',
                                  hintStyle: RythemTypography.bodySmall.copyWith(
                                    color: themeColors.textTertiary.withOpacity(0.6),
                                    fontSize: 11,
                                  ),
                                  isDense: true,
                                  filled: true,
                                  fillColor: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: isDark ? themeColors.glassBorder : const Color(0x18000000),
                                    ),
                                  ),
                                ),
                                onSubmitted: (_) => _handleAddCustomCategory(),
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              onPressed: _handleAddCustomCategory,
                              icon: const Icon(Icons.check_rounded, size: 16),
                              color: const Color(0xFF10B981),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            ),
                            IconButton(
                              onPressed: () => setState(() => _isAddingCategory = false),
                              icon: const Icon(Icons.close_rounded, size: 16),
                              color: themeColors.textTertiary,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],

                      // Scrollable category chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ..._categories.map((cat) {
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
                                          _getCategoryIcon(cat),
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
                            }),
                            if (!_isAddingCategory)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: InkWell(
                                  onTap: () => setState(() => _isAddingCategory = true),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isDark ? themeColors.glassBorder : const Color(0x18000000),
                                        width: 0.8,
                                        style: BorderStyle.solid,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.add_rounded, size: 12, color: themeColors.textTertiary),
                                        const SizedBox(width: 2),
                                        Text(
                                          'Custom',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            color: themeColors.textTertiary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
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
                          hintText: widget.roadmap.isOpenLab
                              ? 'e.g. Robbins Pathology Ch. 4 review, Flutter bugfix #42'
                              : 'e.g. Revision: Dynamic Programming, solve 5 problems',
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

                      // Input 2: Time / Duration (with Hours/Minutes and Live Effort Points preview)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Text(
                                  'DURATION',
                                  style: RythemTypography.labelSmall.copyWith(
                                    color: themeColors.textTertiary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    '(10m = ⚡ 1 beat)',
                                    style: RythemTypography.bodySmall.copyWith(
                                      color: themeColors.textTertiary.withOpacity(0.6),
                                      fontSize: 9.5,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706)).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${_formatDurationReadable(_selectedHours)} • ⚡ ${calculatedEffort.toStringAsFixed(1)} beats',
                              style: RythemTypography.labelSmall.copyWith(
                                color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Preset duration chips row + custom hours field
                      Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _presetHours.map((hours) {
                                  final isSelected = (_selectedHours - hours).abs() < 0.05;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: InkWell(
                                      onTap: () => _selectPresetHours(hours),
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
                                          _formatPresetChip(hours),
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
                            width: 68,
                            height: 34,
                            child: TextField(
                              controller: _hoursController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textAlign: TextAlign.center,
                              style: RythemTypography.labelSmall.copyWith(
                                color: themeColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                              decoration: InputDecoration(
                                hintText: 'hours',
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
                              onChanged: _onCustomHoursChanged,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Input 3: Optional Resource URL
                      Text(
                        'LINK (OPTIONAL)',
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
                                widget.roadmap.isOpenLab
                                    ? 'Logs into Activity Log and counts toward your daily streak.'
                                    : 'Appends to your tracker and counts toward your daily streak.',
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
                              label: widget.roadmap.isOpenLab ? 'Log Task' : 'Add Task',
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
