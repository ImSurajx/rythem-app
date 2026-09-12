import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'glass_container.dart';

enum GlassButtonVariant {
  primary, // Solid white with pure black text
  secondary, // Frosted translucent glass with white text
  ghost, // Minimalist subtle border
}

class GlassButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final GlassButtonVariant variant;
  final double? width;
  final double height;
  final bool isLoading;

  const GlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = GlassButtonVariant.primary,
    this.width,
    this.height = 52.0,
    this.isLoading = false,
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

    final primaryTextColor = themeColors.actionOnPrimary;
    final secondaryTextColor = themeColors.textPrimary;

    Widget content = widget.isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                widget.variant == GlassButtonVariant.primary
                    ? primaryTextColor
                    : secondaryTextColor,
              ),
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
                  color: widget.variant == GlassButtonVariant.primary
                      ? primaryTextColor
                      : secondaryTextColor,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: widget.variant == GlassButtonVariant.primary
                    ? RythemTypography.button.copyWith(color: primaryTextColor)
                    : RythemTypography.button.copyWith(color: secondaryTextColor),
              ),
            ],
          );

    Widget buttonBody;
    if (widget.variant == GlassButtonVariant.primary) {
      buttonBody = Container(
        width: widget.width,
        height: widget.height,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: isEnabled
              ? themeColors.actionPrimary
              : themeColors.actionPrimary.withOpacity(0.35),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: content,
      );
    } else {
      buttonBody = GlassContainer(
        width: widget.width,
        height: widget.height,
        borderRadius: BorderRadius.circular(16),
        opacity: widget.variant == GlassButtonVariant.secondary ? 0.12 : 0.04,
        borderColor: widget.variant == GlassButtonVariant.secondary
            ? (isDark ? themeColors.glassBorderHighlight : const Color(0x20000000))
            : (isDark ? themeColors.glassBorder : const Color(0x14000000)),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(child: content),
      );
    }

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
