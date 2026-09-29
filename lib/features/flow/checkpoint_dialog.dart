import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rythem_app/core/database/models/beat_entity.dart';
import 'package:rythem_app/core/theme/colors.dart';
import 'package:rythem_app/core/theme/typography.dart';
import 'package:rythem_app/core/widgets/glass_button.dart';

/// Modal dialog to record a percentage checkpoint and practice reflections for an active topic.
class CheckpointDialog extends StatefulWidget {
  final BeatEntity beat;
  final int initialPercent;
  final String? initialNotes;
  final void Function(int percentage, String notes) onSaveCheckpoint;

  const CheckpointDialog({
    super.key,
    required this.beat,
    this.initialPercent = 0,
    this.initialNotes,
    required this.onSaveCheckpoint,
  });

  static Future<void> show(
    BuildContext context, {
    required BeatEntity beat,
    int initialPercent = 0,
    String? initialNotes,
    required void Function(int percentage, String notes) onSaveCheckpoint,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (ctx) => CheckpointDialog(
        beat: beat,
        initialPercent: initialPercent,
        initialNotes: initialNotes,
        onSaveCheckpoint: onSaveCheckpoint,
      ),
    );
  }

  @override
  State<CheckpointDialog> createState() => _CheckpointDialogState();
}

class _CheckpointDialogState extends State<CheckpointDialog> {
  late final TextEditingController _percentController;
  late final TextEditingController _notesController;
  late int _currentPercent;

  @override
  void initState() {
    super.initState();
    _currentPercent = widget.initialPercent.clamp(0, 100);
    _percentController = TextEditingController(text: _currentPercent.toString());
    _notesController = TextEditingController(text: widget.initialNotes ?? '');
  }

  @override
  void dispose() {
    _percentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _updatePercent(int val) {
    final clamped = val.clamp(0, 100);
    setState(() {
      _currentPercent = clamped;
      _percentController.text = clamped.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeColors = isDark ? RythemColors.dark : RythemColors.light;

    // Calculate effort points
    final deltaPct = (_currentPercent - widget.initialPercent).clamp(0, 100);
    final earnedPoints = widget.beat.effortWeight * (deltaPct / 100.0);
    final totalProgressPoints = widget.beat.effortWeight * (_currentPercent / 100.0);

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.5) : Colors.black.withOpacity(0.12),
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
                color: isDark ? const Color(0xE0161616) : const Color(0xF2FFFFFF),
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
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0x20FFFFFF) : const Color(0x10000000),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.bookmark_added_rounded,
                                  size: 16,
                                  color: themeColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Study Checkpoint',
                                style: RythemTypography.titleMedium.copyWith(
                                  color: themeColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
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
                      const SizedBox(height: 6),
                      Text(
                        widget.beat.title,
                        style: RythemTypography.bodySmall.copyWith(
                          color: themeColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 18),

                      // Input 1: Percentage Completed
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'HOW MUCH COMPLETED (%)',
                            style: RythemTypography.labelSmall.copyWith(
                              color: themeColors.textTertiary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            '$_currentPercent%',
                            style: RythemTypography.labelSmall.copyWith(
                              color: themeColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0x14FFFFFF) : const Color(0x0A000000),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? themeColors.glassBorder : const Color(0x18000000),
                                ),
                              ),
                              child: TextField(
                                controller: _percentController,
                                keyboardType: TextInputType.number,
                                style: RythemTypography.bodyLarge.copyWith(
                                  color: themeColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Enter 0 - 100',
                                  suffixText: '%',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                onChanged: (txt) {
                                  final parsed = int.tryParse(txt);
                                  if (parsed != null) {
                                    setState(() => _currentPercent = parsed.clamp(0, 100));
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Quick adjustment stepper
                          Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0x14FFFFFF) : const Color(0x0A000000),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? themeColors.glassBorder : const Color(0x18000000),
                              ),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_rounded, size: 16),
                                  color: themeColors.textSecondary,
                                  onPressed: () => _updatePercent(_currentPercent - 10),
                                ),
                                Container(
                                  width: 1,
                                  height: 20,
                                  color: isDark ? themeColors.glassBorder : const Color(0x18000000),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_rounded, size: 16),
                                  color: themeColors.textSecondary,
                                  onPressed: () => _updatePercent(_currentPercent + 10),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Proportional Effort Calculation Card
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0x12FFFFFF) : const Color(0x06000000),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Topic Effort: ${widget.beat.effortWeight.toStringAsFixed(1)} pts',
                              style: RythemTypography.bodySmall.copyWith(
                                color: themeColors.textTertiary,
                                fontSize: 10.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                earnedPoints > 0
                                    ? '+${earnedPoints.toStringAsFixed(2)} pts earned'
                                    : '${totalProgressPoints.toStringAsFixed(2)} pts total',
                                style: RythemTypography.labelSmall.copyWith(
                                  color: earnedPoints > 0
                                      ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB))
                                      : themeColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                                textAlign: TextAlign.right,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Input 2: Comments / Notes & Practice Reflections
                      Text(
                        'PRACTICE & REFLECTION NOTES',
                        style: RythemTypography.labelSmall.copyWith(
                          color: themeColors.textTertiary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0x14FFFFFF) : const Color(0x0A000000),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? themeColors.glassBorder : const Color(0x18000000),
                          ),
                        ),
                        child: TextField(
                          controller: _notesController,
                          maxLines: 3,
                          style: RythemTypography.bodyMedium.copyWith(
                            color: themeColors.textPrimary,
                            fontSize: 12.5,
                          ),
                          decoration: InputDecoration(
                            hintText: 'e.g. Watched 20 mins, completed 2 code exercises, understood core concept...',
                            hintStyle: RythemTypography.bodySmall.copyWith(
                              color: themeColors.textTertiary.withOpacity(0.7),
                              fontSize: 12,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Actions
                      Row(
                        children: [
                          Expanded(
                            child: GlassButton(
                              onPressed: () => Navigator.of(context).pop(),
                              label: 'Cancel',
                              variant: GlassButtonVariant.secondary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: GlassButton(
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                Navigator.of(context).pop();
                                widget.onSaveCheckpoint(
                                  _currentPercent,
                                  _notesController.text.trim(),
                                );
                              },
                              label: _currentPercent >= 100
                                  ? 'Complete Topic (100%)'
                                  : 'Save Checkpoint ($_currentPercent%)',
                              variant: GlassButtonVariant.primary,
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
