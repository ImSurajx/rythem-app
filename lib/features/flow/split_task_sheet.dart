import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rythem_app/core/database/models/beat_entity.dart';
import 'package:rythem_app/core/theme/colors.dart';
import 'package:rythem_app/core/theme/typography.dart';
import 'package:rythem_app/core/widgets/glass_button.dart';

/// Modal bottom sheet allowing users to split any task into multiple parts
/// (e.g., 2-hour long videos or multi-week projects across multiple days).
class SplitTaskSheet extends StatefulWidget {
  final BeatEntity beat;
  final Future<void> Function(int totalParts) onSave;

  const SplitTaskSheet({
    super.key,
    required this.beat,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    required BeatEntity beat,
    required Future<void> Function(int totalParts) onSave,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (ctx) => SplitTaskSheet(beat: beat, onSave: onSave),
    );
  }

  @override
  State<SplitTaskSheet> createState() => _SplitTaskSheetState();
}

class _SplitTaskSheetState extends State<SplitTaskSheet> {
  late int _selectedParts;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Default to existing totalParts, or 2 if currently 1
    _selectedParts = widget.beat.totalParts > 1 ? widget.beat.totalParts : 2;
  }

  void _increment() {
    if (_selectedParts < 10) {
      HapticFeedback.selectionClick();
      setState(() => _selectedParts++);
    }
  }

  void _decrement() {
    if (_selectedParts > 2) {
      HapticFeedback.selectionClick();
      setState(() => _selectedParts--);
    }
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();
    try {
      await widget.onSave(_selectedParts);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleResetToSingle() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();
    try {
      await widget.onSave(1);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _isSaving = false);
    }
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
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xEE121826)
                  : const Color(0xF5FFFFFF),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: isDark ? const Color(0x33FFFFFF) : const Color(0x22000000),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 30,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0x40FFFFFF) : const Color(0x30000000),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF6366F1).withOpacity(0.35),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.call_split_rounded,
                        size: 20,
                        color: Color(0xFF818CF8),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Complete in Parts',
                            style: RythemTypography.titleLarge.copyWith(
                              color: themeColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Break this lesson across multiple study sessions or days',
                            style: RythemTypography.bodySmall.copyWith(
                              color: themeColors.textTertiary,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Beat Title Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0x16FFFFFF) : const Color(0x0A000000),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? const Color(0x1AFFFFFF) : const Color(0x12000000),
                      width: 0.8,
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
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            '${widget.beat.effortWeight.toStringAsFixed(1)} effort total',
                            style: RythemTypography.labelSmall.copyWith(
                              color: themeColors.textTertiary,
                              fontSize: 10.5,
                            ),
                          ),
                          if (widget.beat.isMultiPart) ...[
                            Text(
                              '  •  ',
                              style: TextStyle(color: themeColors.textTertiary, fontSize: 10),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withOpacity(0.18),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Part ${widget.beat.completedParts} of ${widget.beat.totalParts} done',
                                style: RythemTypography.labelSmall.copyWith(
                                  color: const Color(0xFFA5B4FC),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Quick Presets Label
                Text(
                  'QUICK PRESETS',
                  style: RythemTypography.labelSmall.copyWith(
                    color: themeColors.textTertiary,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 8),

                // Presets Row
                Row(
                  children: [
                    _buildPresetChip(
                      label: '2 Parts (50%)',
                      parts: 2,
                      isDark: isDark,
                      themeColors: themeColors,
                    ),
                    const SizedBox(width: 8),
                    _buildPresetChip(
                      label: '3 Parts (33%)',
                      parts: 3,
                      isDark: isDark,
                      themeColors: themeColors,
                    ),
                    const SizedBox(width: 8),
                    _buildPresetChip(
                      label: '4 Parts (25%)',
                      parts: 4,
                      isDark: isDark,
                      themeColors: themeColors,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Custom Counter Stepper
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0x18FFFFFF) : const Color(0x0C000000),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0x22FFFFFF) : const Color(0x18000000),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Custom Parts',
                            style: RythemTypography.bodyMedium.copyWith(
                              color: themeColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '~${(widget.beat.effortWeight / _selectedParts).toStringAsFixed(1)} effort per part',
                            style: RythemTypography.labelSmall.copyWith(
                              color: themeColors.textTertiary,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          _buildStepperButton(
                            icon: Icons.remove_rounded,
                            onTap: _selectedParts > 2 ? _decrement : null,
                            isDark: isDark,
                          ),
                          Container(
                            constraints: const BoxConstraints(minWidth: 44),
                            alignment: Alignment.center,
                            child: Text(
                              '$_selectedParts',
                              style: RythemTypography.titleLarge.copyWith(
                                color: themeColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          _buildStepperButton(
                            icon: Icons.add_rounded,
                            onTap: _selectedParts < 10 ? _increment : null,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // Action Buttons
                GlassButton(
                  label: widget.beat.totalParts == _selectedParts
                      ? 'Keep $_selectedParts Parts'
                      : 'Split into $_selectedParts Parts',
                  icon: Icons.check_rounded,
                  variant: GlassButtonVariant.primary,
                  onPressed: _isSaving ? null : _handleSave,
                ),

                if (widget.beat.isMultiPart) ...[
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _isSaving ? null : _handleResetToSingle,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Text(
                      'Reset to Single Task (1 Part)',
                      style: RythemTypography.bodySmall.copyWith(
                        color: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChip({
    required String label,
    required int parts,
    required bool isDark,
    required RythemColorTokens themeColors,
  }) {
    final isSelected = _selectedParts == parts;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedParts = parts);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF6366F1).withOpacity(isDark ? 0.35 : 0.20)
                : (isDark ? const Color(0x14FFFFFF) : const Color(0x0A000000)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF818CF8)
                  : (isDark ? const Color(0x18FFFFFF) : const Color(0x12000000)),
              width: isSelected ? 1.4 : 0.8,
            ),
          ),
          child: Text(
            label,
            style: RythemTypography.labelSmall.copyWith(
              color: isSelected
                  ? (isDark ? Colors.white : const Color(0xFF4F46E5))
                  : themeColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 10.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildStepperButton({
    required IconData icon,
    required VoidCallback? onTap,
    required bool isDark,
  }) {
    final isEnabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isEnabled
              ? (isDark ? const Color(0x28FFFFFF) : const Color(0x14000000))
              : (isDark ? const Color(0x0DFFFFFF) : const Color(0x06000000)),
          border: Border.all(
            color: isEnabled
                ? (isDark ? const Color(0x35FFFFFF) : const Color(0x1E000000))
                : Colors.transparent,
            width: 0.8,
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: isEnabled
              ? (isDark ? Colors.white : Colors.black87)
              : (isDark ? const Color(0x40FFFFFF) : const Color(0x30000000)),
        ),
      ),
    );
  }
}
