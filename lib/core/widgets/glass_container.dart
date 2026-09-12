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

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius,
    this.blur = 16.0,
    this.opacity = 0.08,
    this.borderColor,
    this.borderGradient,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(20);
    final themeColors = RythemColors.of(context);
    final isDark = themeColors.isDark;

    // Dark mode: translucent liquid glass with deep ambient shadow
    // Light mode (Apple Control Center): frosted white plate with soft diffuse shadow & top specular highlight
    final resolvedBg = backgroundColor ?? (isDark ? Colors.white.withOpacity(opacity) : Colors.white.withOpacity(0.72));
    final resolvedBorderColor = borderColor ?? (isDark ? themeColors.glassBorder : const Color(0x18000000));
    final resolvedShadow = isDark
        ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.45),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ]
        : [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ];

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: effectiveRadius,
        boxShadow: resolvedShadow,
      ),
      child: ClipRRect(
        borderRadius: effectiveRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: resolvedBg,
              borderRadius: effectiveRadius,
              border: Border.all(
                color: resolvedBorderColor,
                width: 1.0,
              ),
              gradient: borderGradient,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
