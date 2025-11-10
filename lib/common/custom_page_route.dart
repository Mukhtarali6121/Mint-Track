import 'package:flutter/material.dart';
import 'animation_utils.dart';

/// Custom page route with slide and fade transitions
class CustomPageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;
  final bool slideFromRight;

  CustomPageRoute({
    required this.child,
    this.slideFromRight = true,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: AnimationUtils.normalDuration,
          reverseTransitionDuration: AnimationUtils.normalDuration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Fade transition
            final fadeAnimation = Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: AnimationUtils.smoothCurve,
              ),
            );

            // Slide transition
            final slideAnimation = Tween<Offset>(
              begin: slideFromRight ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: AnimationUtils.smoothCurve,
              ),
            );

            return FadeTransition(
              opacity: fadeAnimation,
              child: SlideTransition(
                position: slideAnimation,
                child: child,
              ),
            );
          },
        );
}

