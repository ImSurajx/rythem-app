import 'package:flutter/material.dart';
import '../theme/colors.dart';

class GlassProgressBar extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double height;
  final BorderRadius? borderRadius;
  final bool showGlow;

  const GlassProgressBar({
    super.key,
    required this.progress,
    this.height = 8.0,
    this.borderRadius,
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0);
    final effectiveRadius = borderRadius ?? BorderRadius.circular(height / 2);
    final themeColors = RythemColors.of(context);
    final isDark = themeColors.isDark;

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
                  color: themeColors.progressFill,
                  borderRadius: effectiveRadius,
                  boxShadow: showGlow && clampedProgress > 0
                      ? [
                          BoxShadow(
                            color: isDark
                                ? Colors.white.withOpacity(0.35)
                                : Colors.black.withOpacity(0.15),
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
