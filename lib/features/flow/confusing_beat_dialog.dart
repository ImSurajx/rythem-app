import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rythem_app/core/ai/ai.dart';
import 'package:rythem_app/core/database/models/beat_entity.dart';
import 'package:rythem_app/core/theme/colors.dart';
import 'package:rythem_app/core/theme/typography.dart';
import 'package:rythem_app/core/widgets/glass_button.dart';

/// Non-punitive dialog to flag confusion or an obstacle on a beat per `docs/design.md` §2.
/// Allows the user to record friction without penalty, guilt, or breaking streaks.
class ConfusingBeatDialog extends StatefulWidget {
  final BeatEntity beat;
  final ValueChanged<String>? onFlagSaved;
  final LocalInferenceService inferenceService;

  ConfusingBeatDialog({
    super.key,
    required this.beat,
    this.onFlagSaved,
    LocalInferenceService? inferenceService,
  }) : inferenceService = inferenceService ?? LocalInferenceService();

  static Future<void> show(
    BuildContext context, {
    required BeatEntity beat,
    ValueChanged<String>? onFlagSaved,
    LocalInferenceService? inferenceService,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (ctx) => ConfusingBeatDialog(
        beat: beat,
        onFlagSaved: onFlagSaved,
        inferenceService: inferenceService ?? LocalInferenceService(),
      ),
    );
  }

  @override
  State<ConfusingBeatDialog> createState() => _ConfusingBeatDialogState();
}

class _ConfusingBeatDialogState extends State<ConfusingBeatDialog> {
  late final TextEditingController _noteController;
  bool _isLoadingAiExplanation = false;
  String? _aiExplanation;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _fetchAiExplanation() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isLoadingAiExplanation = true;
    });

    try {
      final text = await widget.inferenceService.explainConfusingBeat(
        beatTitle: widget.beat.title,
      );
      if (mounted) {
        setState(() {
          _aiExplanation = text;
          _isLoadingAiExplanation = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingAiExplanation = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeColors = isDark ? RythemColors.dark : RythemColors.light;

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
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              padding: const EdgeInsets.all(24),
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.help_outline_rounded,
                          size: 20,
                          color: themeColors.textPrimary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'FLAG FRICTION / CONFUSION',
                          style: RythemTypography.labelSmall.copyWith(
                            color: themeColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.beat.title,
                      style: RythemTypography.titleMedium.copyWith(
                        color: themeColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Record where you felt stuck or had questions. Zero penalty, zero streak disruption.',
                      style: RythemTypography.bodySmall.copyWith(
                        color: themeColors.textTertiary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_isLoadingAiExplanation) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? themeColors.glassBorder : const Color(0x14000000),
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(themeColors.textPrimary),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'AI Mentor synthesizing offline explanation...',
                                style: RythemTypography.bodySmall.copyWith(
                                  color: themeColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (_aiExplanation != null) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0x18FFFFFF) : const Color(0x0A000000),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? themeColors.glassBorderHighlight : const Color(0x20000000),
                            ),
                          ),
                          child: Text(
                            _aiExplanation!,
                            style: RythemTypography.bodySmall.copyWith(
                              color: themeColors.textPrimary,
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ] else ...[
                        GestureDetector(
                          onTap: _fetchAiExplanation,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark ? themeColors.glassBorder : const Color(0x18000000),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.psychology_outlined, size: 14, color: themeColors.textPrimary),
                                const SizedBox(width: 6),
                                Text(
                                  'Ask AI Mentor for quick breakdown',
                                  style: RythemTypography.labelSmall.copyWith(
                                    color: themeColors.textPrimary,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    TextField(
                      controller: _noteController,
                      maxLines: 3,
                      autofocus: true,
                      style: RythemTypography.bodyMedium.copyWith(
                        color: themeColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g. Concept unclear at 12:45, need alternate resource...',
                        hintStyle: RythemTypography.bodySmall.copyWith(
                          color: themeColors.textTertiary.withOpacity(0.6),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withOpacity(0.06)
                            : Colors.black.withOpacity(0.04),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark ? themeColors.glassBorder : const Color(0x20000000),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: isDark ? themeColors.glassBorderHighlight : Colors.black87,
                            width: 1.2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            'Cancel',
                            style: RythemTypography.labelSmall.copyWith(
                              color: themeColors.textTertiary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GlassButton(
                          label: 'Save Flag',
                          variant: GlassButtonVariant.primary,
                          icon: Icons.bookmark_add_outlined,
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            final note = _noteController.text.trim();
                            widget.onFlagSaved?.call(note.isEmpty ? 'Flagged as confusing' : note);
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: isDark ? const Color(0xFF222222) : Colors.black87,
                                content: Text(
                                  'Flag saved. Flow continues uninterrupted.',
                                  style: RythemTypography.bodySmall.copyWith(color: Colors.white),
                                ),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          },
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
    );
  }
}
