import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/colors.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final double blur;
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
    this.blur = 12.0,
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

    final effectiveBlur = blur.clamp(4.0, 14.0);

    final innerContent = RepaintBoundary(
      child: ClipRRect(
        borderRadius: effectiveRadius,
        child: enableBlur
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: effectiveBlur, sigmaY: effectiveBlur),
                child: containerBody,
              )
            : containerBody,
      ),
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
