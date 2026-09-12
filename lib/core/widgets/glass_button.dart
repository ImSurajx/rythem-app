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

    Widget content = widget.isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                widget.variant == GlassButtonVariant.primary
                    ? RythemColors.actionOnPrimary
                    : RythemColors.actionPrimary,
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
                      ? RythemColors.actionOnPrimary
                      : RythemColors.actionPrimary,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: widget.variant == GlassButtonVariant.primary
                    ? RythemTypography.button
                    : RythemTypography.button.copyWith(color: RythemColors.textPrimary),
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
          color: isEnabled ? RythemColors.actionPrimary : RythemColors.actionPrimary.withOpacity(0.35),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(0.12),
              blurRadius: 18,
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
            ? RythemColors.glassBorderHighlight
            : RythemColors.glassBorder,
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
