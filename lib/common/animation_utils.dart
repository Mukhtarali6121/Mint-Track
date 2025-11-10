import 'package:flutter/material.dart';

/// Animation utility constants and helpers
class AnimationUtils {
  // Common animation durations
  static const Duration fastDuration = Duration(milliseconds: 150);
  static const Duration normalDuration = Duration(milliseconds: 300);
  static const Duration slowDuration = Duration(milliseconds: 500);
  static const Duration verySlowDuration = Duration(milliseconds: 800);

  // Common animation curves
  static const Curve defaultCurve = Curves.easeInOut;
  static const Curve bounceCurve = Curves.easeOutBack;
  static const Curve smoothCurve = Curves.easeOutCubic;
  static const Curve springCurve = Curves.elasticOut;

  // Staggered animation delays
  static Duration getStaggerDelay(int index, {Duration baseDelay = const Duration(milliseconds: 50)}) {
    return baseDelay * index;
  }

  /// Creates a fade-in animation
  static Widget fadeIn({
    required Widget child,
    Duration duration = normalDuration,
    Curve curve = defaultCurve,
    Duration? delay,
  }) {
    if (delay != null) {
      return TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: duration,
        curve: curve,
        builder: (context, value, child) {
          return Opacity(opacity: value, child: child);
        },
        child: child,
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        return Opacity(opacity: value, child: child);
      },
      child: child,
    );
  }

  /// Creates a slide-up animation
  static Widget slideUp({
    required Widget child,
    Duration duration = normalDuration,
    Curve curve = smoothCurve,
    double offset = 0.3,
  }) {
    return TweenAnimationBuilder<Offset>(
      tween: Tween<Offset>(
        begin: Offset(0, offset),
        end: Offset.zero,
      ),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        return Transform.translate(
          offset: value * MediaQuery.of(context).size.height,
          child: child,
        );
      },
      child: child,
    );
  }

  /// Creates a scale animation
  static Widget scale({
    required Widget child,
    required double scale,
    Duration duration = fastDuration,
    Curve curve = defaultCurve,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1.0, end: scale),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: child,
    );
  }

  /// Creates a pulse animation
  static Widget pulse({
    required Widget child,
    Duration duration = const Duration(milliseconds: 1000),
    double minScale = 0.95,
    double maxScale = 1.0,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: minScale, end: maxScale),
      duration: duration,
      curve: Curves.easeInOut,
      onEnd: () {
        // This will be handled by the parent animation controller if needed
      },
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: child,
    );
  }
}

/// Reusable animated button wrapper
class AnimatedButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Duration duration;
  final Curve curve;
  final double pressedScale;

  const AnimatedButton({
    super.key,
    required this.child,
    this.onPressed,
    this.duration = AnimationUtils.fastDuration,
    this.curve = AnimationUtils.bounceCurve,
    this.pressedScale = 0.95,
  });

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (widget.onPressed != null) {
          setState(() => _isPressed = true);
        }
      },
      onTapUp: (_) {
        if (widget.onPressed != null) {
          setState(() => _isPressed = false);
          widget.onPressed!();
        }
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
      },
      child: AnimatedScale(
        scale: _isPressed ? widget.pressedScale : 1.0,
        duration: widget.duration,
        curve: widget.curve,
        child: widget.child,
      ),
    );
  }
}

/// Staggered list animation wrapper
class StaggeredListAnimation extends StatelessWidget {
  final Widget child;
  final int index;
  final Duration baseDelay;
  final Duration duration;

  const StaggeredListAnimation({
    super.key,
    required this.child,
    required this.index,
    this.baseDelay = const Duration(milliseconds: 50),
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    final delay = AnimationUtils.getStaggerDelay(index, baseDelay: baseDelay);
    
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: duration + delay,
      curve: AnimationUtils.smoothCurve,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

