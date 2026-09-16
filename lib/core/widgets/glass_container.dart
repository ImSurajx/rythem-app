import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Performance tiers for frosted glass rendering.
enum GlassLevel {
  /// Level 0: Pure translucent surface, specular border, soft shadow.
  /// 0 GPU blur passes. Extremely lightweight and fast for repeated cards & lists.
  matte,

  /// Level 1: Localized subtle blur (sigma: 8-10). Used for primary section cards.
  frosted,

  /// Level 2: Refined blur (sigma: 16) for focal floating navigation bars and dialogs.
  premium,

  /// Level 3: Refined blur with specular highlight for active hero surfaces.
  liquid,
}

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final GlassLevel level;
  final double? blur;
  final double opacity;
  final Color? borderColor;
  final Gradient? borderGradient;
  final Color? backgroundColor;
  final bool enableBlur;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius,
    this.level = GlassLevel.frosted,
    this.blur,
    this.opacity = 0.09,
    this.borderColor,
    this.borderGradient,
    this.backgroundColor,
    this.enableBlur = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(20);
    final themeColors = RythemColors.of(context);
    final isDark = themeColors.isDark;

    // Dark mode: translucent liquid glass with specular highlights & deep ambient shadow
    // Light mode (Apple Safari / Music): luminous frosted plate with top specular rim
    final resolvedBg = backgroundColor ??
        (isDark
            ? Color.fromRGBO(25, 26, 30, opacity.clamp(0.0, 1.0))
                .withOpacity((opacity * 1.5).clamp(0.04, 0.28))
            : themeColors.glassBackground);

    final effectiveBorderGradient = borderGradient ??
        (borderColor != null ? null : themeColors.specularBorderGradient);
    final resolvedBorderColor = borderColor ??
        (isDark ? themeColors.glassBorder : themeColors.glassBorder);

    final resolvedShadow = isDark
        ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.55),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ]
        : [
            BoxShadow(
              color: const Color(0xFF0E1420).withOpacity(0.06),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ];

    final containerBody = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: resolvedBg,
        borderRadius: effectiveRadius,
      ),
      child: child,
    );

    final double resolvedBlur;
    if (blur != null) {
      resolvedBlur = blur!.clamp(0.0, 24.0);
    } else {
      switch (level) {
        case GlassLevel.matte:
          resolvedBlur = 0.0;
          break;
        case GlassLevel.frosted:
          resolvedBlur = 8.0;
          break;
        case GlassLevel.premium:
        case GlassLevel.liquid:
          resolvedBlur = 16.0;
          break;
      }
    }

    final bool shouldApplyBlur = enableBlur && level != GlassLevel.matte && resolvedBlur > 0.0;

    final innerContent = shouldApplyBlur
        ? RepaintBoundary(
            child: ClipRRect(
              borderRadius: effectiveRadius,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: resolvedBlur, sigmaY: resolvedBlur),
                child: containerBody,
              ),
            ),
          )
        : ClipRRect(
            borderRadius: effectiveRadius,
            child: containerBody,
          );

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: effectiveRadius,
        boxShadow: resolvedShadow,
        gradient: effectiveBorderGradient,
        border: effectiveBorderGradient == null
            ? Border.all(color: resolvedBorderColor, width: 1.0)
            : null,
      ),
      padding: effectiveBorderGradient != null
          ? const EdgeInsets.all(1.0)
          : EdgeInsets.zero,
      child: innerContent,
    );
  }
}
