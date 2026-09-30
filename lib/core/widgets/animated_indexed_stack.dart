import 'package:flutter/material.dart';
import 'package:rythem_app/core/theme/animation_config.dart';

/// A stack that smoothly animates transitions between index changes with cross-fade
/// and gentle scaling, while strictly preserving state and scroll positions of all children.
class AnimatedIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final Duration duration;

  const AnimatedIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 320),
  });

  @override
  State<AnimatedIndexedStack> createState() => _AnimatedIndexedStackState();
}

class _AnimatedIndexedStackState extends State<AnimatedIndexedStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  int _currentIndex = 0;
  int _previousIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.index;
    _previousIndex = widget.index;
    _controller = AnimationController(
      vsync: this,
      duration: AppAnimations.duration(widget.duration.inMilliseconds),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant AnimatedIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != _currentIndex) {
      _previousIndex = _currentIndex;
      _currentIndex = widget.index;
      if (AppAnimations.isTest) {
        _controller.value = 1.0;
      } else {
        _controller.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppAnimations.isTest) {
      return IndexedStack(
        index: widget.index,
        children: widget.children,
      );
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final isAnimating = _controller.isAnimating;
        return Stack(
          fit: StackFit.expand,
          children: List.generate(widget.children.length, (i) {
            final isCurrent = i == _currentIndex;
            final isPrevious = i == _previousIndex;

            // When idle, keep offstage children alive with maintainState: true
            if (!isCurrent && (!isAnimating || !isPrevious)) {
              return Visibility(
                maintainState: true,
                visible: false,
                child: widget.children[i],
              );
            }

            final double opacity;
            final double scale;

            if (isCurrent) {
              opacity = isAnimating ? _animation.value : 1.0;
              scale = isAnimating ? (0.985 + 0.015 * _animation.value) : 1.0;
            } else {
              opacity = (1.0 - _animation.value).clamp(0.0, 1.0);
              scale = (1.0 - 0.015 * _animation.value).clamp(0.985, 1.0);
            }

            return IgnorePointer(
              ignoring: !isCurrent,
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: scale,
                  child: widget.children[i],
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
