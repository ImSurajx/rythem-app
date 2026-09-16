import 'package:flutter/material.dart';

/// Provides ultra-smooth, lightweight page route transitions with zero jank.
/// Combines subtle cubic deceleration fade and micro-slide.
class SmoothPageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;

  SmoothPageRoute({
    required this.child,
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: const Duration(milliseconds: 260),
          reverseTransitionDuration: const Duration(milliseconds: 220),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            return FadeTransition(
              opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.025),
                  end: Offset.zero,
                ).animate(curvedAnimation),
                child: child,
              ),
            );
          },
        );
}
