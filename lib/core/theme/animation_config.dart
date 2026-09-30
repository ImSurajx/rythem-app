import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Central animation configuration for Rythem.
/// Ensures 60/120fps fluid animations on real devices while automatically
/// preventing pending tickers/timers or infinite loops during headless widget tests.
class AppAnimations {
  static bool get isTest {
    final typeName = WidgetsBinding.instance.runtimeType.toString();
    return typeName.contains('Test') || typeName.contains('Automated');
  }

  /// Responsive duration for smooth transitions (zero during widget tests).
  static Duration duration(int ms) {
    if (isTest) return Duration.zero;
    return Duration(milliseconds: ms);
  }

  /// Staggered delay for cascading item entrances (zero during widget tests).
  static Duration staggerDelay(int index, {int stepMs = 25}) {
    if (isTest) return Duration.zero;
    return Duration(milliseconds: index * stepMs);
  }

  /// Whether infinite repeating ambient animations should loop (disabled during tests to allow pumpAndSettle).
  static bool get shouldLoopAmbient => !isTest;
}

extension SmoothEntranceExtension on Widget {
  /// Fluid staggered entry transition with cubic curves and fade-in.
  /// Automatically bypassed during headless widget tests to ensure instant execution and zero pending timers.
  Widget smoothEntrance({
    Key? key,
    int index = 0,
    int stepMs = 25,
    int durationMs = 240,
    double slideBeginY = 0.05,
  }) {
    if (AppAnimations.isTest) return this;
    return animate(key: key)
        .fadeIn(duration: Duration(milliseconds: durationMs), curve: Curves.easeOutCubic)
        .slideY(
          begin: slideBeginY,
          end: 0,
          duration: Duration(milliseconds: durationMs),
          curve: Curves.easeOutCubic,
          delay: Duration(milliseconds: index * stepMs),
        );
  }

  /// Ambient glowing shimmer for the active focus beat.
  /// Automatically bypassed during tests to prevent pumpAndSettle timeouts.
  Widget activeFocusAmbientGlow({required bool isDark}) {
    if (AppAnimations.isTest) return this;
    return animate(onPlay: (controller) => controller.repeat(reverse: true))
        .shimmer(
          duration: const Duration(milliseconds: 3000),
          color: isDark ? const Color(0x1810B981) : const Color(0x12059669),
        );
  }
}
