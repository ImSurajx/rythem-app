import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// An ultra-smooth, hardware-accelerated ambient atmospheric lighting canvas.
///
/// Paints soft, deeply diffused radial color orbs beneath frosted glass layers,
/// producing authentic liquid glass refraction identical to Apple VisionOS and
/// macOS Sonoma dynamic desktops without taxing GPU frame budgets.
class AmbientAuroraCanvas extends StatelessWidget {
  final Widget child;
  final ThemePalette? palette;
  final List<AmbientOrbConfig>? customOrbs;
  final bool animate;

  const AmbientAuroraCanvas({
    super.key,
    required this.child,
    this.palette,
    this.customOrbs,
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) {
    final themeColors = RythemColors.of(context);
    final activePalette = palette ?? themeColors.palette;
    final resolvedOrbs = customOrbs ??
        (themeColors.isDark
            ? RythemColors.resolve(isDark: true, palette: activePalette).ambientOrbs
            : RythemColors.resolve(isDark: false, palette: activePalette).ambientOrbs);

    return RepaintBoundary(
      child: CustomPaint(
        painter: _AmbientAuroraPainter(
          baseGradient: themeColors.canvasGradient,
          orbs: resolvedOrbs,
        ),
        child: child,
      ),
    );
  }
}

class _AmbientAuroraPainter extends CustomPainter {
  final LinearGradient baseGradient;
  final List<AmbientOrbConfig> orbs;

  const _AmbientAuroraPainter({
    required this.baseGradient,
    required this.orbs,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final rect = Offset.zero & size;

    // 1. Draw base canvas gradient
    final basePaint = Paint()..shader = baseGradient.createShader(rect);
    canvas.drawRect(rect, basePaint);

    // 2. Draw atmospheric ambient orbs with soft radial falloff
    for (final orb in orbs) {
      if (orb.opacity <= 0.0) continue;
      final orbPaint = Paint()
        ..shader = RadialGradient(
          center: orb.alignment,
          radius: orb.radius,
          colors: [
            orb.color.withOpacity(orb.opacity),
            orb.color.withOpacity(orb.opacity * 0.45),
            orb.color.withOpacity(0.0),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(rect);

      canvas.drawRect(rect, orbPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientAuroraPainter oldDelegate) {
    if (baseGradient != oldDelegate.baseGradient || orbs.length != oldDelegate.orbs.length) {
      return true;
    }
    for (int i = 0; i < orbs.length; i++) {
      if (orbs[i].alignment != oldDelegate.orbs[i].alignment ||
          orbs[i].color != oldDelegate.orbs[i].color ||
          orbs[i].opacity != oldDelegate.orbs[i].opacity ||
          orbs[i].radius != oldDelegate.orbs[i].radius) {
        return true;
      }
    }
    return false;
  }
}
