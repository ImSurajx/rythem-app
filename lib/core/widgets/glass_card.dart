import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'glass_container.dart';

class GlassCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final GlassLevel level;
  final double? blur;
  final double opacity;
  final Color? borderColor;

  const GlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.borderRadius,
    this.level = GlassLevel.frosted,
    this.blur,
    this.opacity = 0.09,
    this.borderColor,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _scaleAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.onTap != null) {
      _initController();
    }
  }

  void _initController() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.985).animate(
      CurvedAnimation(parent: _controller!, curve: Curves.easeOutQuart),
    );
  }

  @override
  void didUpdateWidget(GlassCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onTap != null && _controller == null) {
      _initController();
    } else if (widget.onTap == null && _controller != null) {
      _controller?.dispose();
      _controller = null;
      _scaleAnimation = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap != null && _controller != null) {
      _controller!.forward();
      HapticFeedback.lightImpact();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onTap != null && _controller != null) {
      _controller!.reverse();
    }
  }

  void _onTapCancel() {
    if (widget.onTap != null && _controller != null) {
      _controller!.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardContent = GlassContainer(
      padding: widget.padding,
      margin: widget.margin,
      borderRadius: widget.borderRadius,
      level: widget.level,
      blur: widget.blur,
      opacity: widget.opacity,
      borderColor: widget.borderColor,
      child: widget.child,
    );

    // If static card without tap interaction, render directly without ticker/transform overhead
    if (widget.onTap == null) {
      return cardContent;
    }

    final scaleAnim = _scaleAnimation;
    if (scaleAnim == null) {
      return GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: cardContent,
      );
    }

    return AnimatedBuilder(
      animation: scaleAnim,
      builder: (context, child) => Transform.scale(
        scale: scaleAnim.value,
        child: child,
      ),
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: cardContent,
      ),
    );
  }
}
