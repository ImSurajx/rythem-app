import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

enum GlassButtonVariant {
  primary, // Translucent frosted glass with floating specular highlight
  secondary, // Subtle translucent frosted glass with soft border
  ghost, // Minimalist transparent glass with thin subtle border
}

class GlassButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final GlassButtonVariant variant;
  final double? width;
  final double height;
  final bool isLoading;
  final bool enableBlur;

  const GlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = GlassButtonVariant.primary,
    this.width,
    this.height = 52.0,
    this.isLoading = false,
    this.enableBlur = true,
  });

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      _animController.forward();
      HapticFeedback.lightImpact();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      _animController.reverse();
    }
  }

  void _handleTapCancel() {
    if (widget.onPressed != null && !widget.isLoading) {
      _animController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null && !widget.isLoading;
    final themeColors = RythemColors.of(context);
    final isDark = themeColors.isDark;

    final Color textColor;
    final Color backgroundColor;
    final Color borderColor;
    final List<BoxShadow> shadows;

    if (widget.variant == GlassButtonVariant.primary) {
      textColor = themeColors.textPrimary;
      if (isDark) {
        backgroundColor = isEnabled ? const Color(0x1EFFFFFF) : const Color(0x0EFFFFFF);
        borderColor = isEnabled ? const Color(0x32FFFFFF) : const Color(0x1CFFFFFF);
        shadows = isEnabled
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ]
            : [];
      } else {
        backgroundColor = isEnabled ? const Color(0x18000000) : const Color(0x0A000000);
        borderColor = isEnabled ? const Color(0x1E000000) : const Color(0x12000000);
        shadows = isEnabled
            ? [
                BoxShadow(
                  color: const Color(0xFF0E1420).withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : [];
      }
    } else if (widget.variant == GlassButtonVariant.secondary) {
      textColor = themeColors.textPrimary;
      if (isDark) {
        backgroundColor = isEnabled ? const Color(0x18FFFFFF) : const Color(0x0CFFFFFF);
        borderColor = isEnabled ? const Color(0x2AFFFFFF) : const Color(0x18FFFFFF);
        shadows = isEnabled
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : [];
      } else {
        backgroundColor = isEnabled ? const Color(0x12000000) : const Color(0x06000000);
        borderColor = isEnabled ? const Color(0x18000000) : const Color(0x10000000);
        shadows = isEnabled
            ? [
                BoxShadow(
                  color: const Color(0xFF0E1420).withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : [];
      }
    } else {
      // ghost
      textColor = themeColors.textSecondary;
      backgroundColor = Colors.transparent;
      borderColor = isDark ? const Color(0x20FFFFFF) : const Color(0x14000000);
      shadows = [];
    }

    Widget content = widget.isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(textColor),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: 18,
                  color: textColor,
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RythemTypography.button.copyWith(
                    color: textColor,
                    fontWeight: widget.variant == GlassButtonVariant.primary
                        ? FontWeight.w600
                        : FontWeight.w500,
                  ),
                ),
              ),
            ],
          );

    final horizontalPadding = (widget.width != null && widget.width! < 120) ? 12.0 : 22.0;

    final innerContainer = Container(
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: widget.variant == GlassButtonVariant.primary ? 1.0 : 0.8,
        ),
      ),
      child: content,
    );

    final buttonBody = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: shadows,
      ),
      child: widget.enableBlur
          ? ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: innerContainer,
              ),
            )
          : innerContainer,
    );

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: child,
      ),
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: isEnabled ? widget.onPressed : null,
        behavior: HitTestBehavior.opaque,
        child: buttonBody,
      ),
    );
  }
}
