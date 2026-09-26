import 'package:flutter/material.dart';
import '../theme/colors.dart';

class GlassProgressBar extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double height;
  final BorderRadius? borderRadius;
  final bool showGlow;
  final Color? customColor;
  final Gradient? customGradient;

  const GlassProgressBar({
    super.key,
    required this.progress,
    this.height = 8.0,
    this.borderRadius,
    this.showGlow = true,
    this.customColor,
    this.customGradient,
  });

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0);
    final effectiveRadius = borderRadius ?? BorderRadius.circular(height / 2);
    final themeColors = RythemColors.of(context);
    final isDark = themeColors.isDark;

    final resolvedFillColor = customColor ??
        (customGradient == null && themeColors.palette == ThemePalette.studio
            ? themeColors.progressFill
            : null);
    final resolvedGradient = customGradient ??
        (customColor == null && themeColors.palette != ThemePalette.studio
            ? themeColors.accentGradient
            : null);
    final glowColor = customColor ??
        (themeColors.palette != ThemePalette.studio
            ? themeColors.accentPrimary
            : (isDark ? Colors.white : Colors.black));

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: themeColors.progressTrack,
        borderRadius: effectiveRadius,
        border: Border.all(
          color: isDark ? themeColors.glassBorder : const Color(0x14000000),
          width: 0.8,
        ),
      ),
      child: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final fillWidth = constraints.maxWidth * clampedProgress;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                width: fillWidth,
                height: height,
                decoration: BoxDecoration(
                  color: resolvedFillColor,
                  gradient: resolvedGradient,
                  borderRadius: effectiveRadius,
                  boxShadow: showGlow && clampedProgress > 0
                      ? [
                          BoxShadow(
                            color: glowColor.withOpacity(isDark ? 0.35 : 0.18),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
