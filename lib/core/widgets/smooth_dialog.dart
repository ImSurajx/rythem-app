import 'package:flutter/material.dart';
import 'package:rythem_app/core/theme/animation_config.dart';

/// Shows a dialog with smooth entrance and exit animations (gentle scale & fade).
/// Automatically degrades to standard dialog during tests to prevent ticker timeouts.
Future<T?> showSmoothDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  String? barrierLabel,
  Color barrierColor = const Color(0x99000000),
  Duration transitionDuration = const Duration(milliseconds: 300),
}) {
  if (AppAnimations.isTest) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: barrierLabel,
      barrierColor: barrierColor,
      builder: builder,
    );
  }

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierLabel ?? 'Dismiss',
    barrierColor: barrierColor,
    transitionDuration: transitionDuration,
    pageBuilder: (buildContext, animation, secondaryAnimation) {
      return builder(buildContext);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curvedAnimation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(curvedAnimation),
          child: child,
        ),
      );
    },
  );
}
