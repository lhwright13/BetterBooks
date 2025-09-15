import 'package:flutter/material.dart';
import 'dart:ui';

/// Smooth fade transition for modal dialogs and overlays
class FadePageTransition extends PageRouteBuilder {
  final Widget child;
  final RouteSettings? routeSettings;
  final Duration duration;
  final Curve curve;
  final bool opaque;

  FadePageTransition({
    required this.child,
    this.routeSettings,
    this.duration = const Duration(milliseconds: 250),
    this.curve = Curves.easeInOut,
    this.opaque = true,
  }) : super(
    pageBuilder: (context, animation, secondaryAnimation) => child,
    settings: routeSettings,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    opaque: opaque,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fadeAnimation = animation.drive(
        Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve)),
      );

      return FadeTransition(
        opacity: fadeAnimation,
        child: child,
      );
    },
  );
}

/// Fade transition with scale effect for dialogs
class ScaleFadePageTransition extends PageRouteBuilder {
  final Widget child;
  final RouteSettings? routeSettings;
  final Duration duration;
  final double initialScale;

  ScaleFadePageTransition({
    required this.child,
    this.routeSettings,
    this.duration = const Duration(milliseconds: 300),
    this.initialScale = 0.8,
  }) : super(
    pageBuilder: (context, animation, secondaryAnimation) => child,
    settings: routeSettings,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    opaque: false,
    barrierColor: Colors.black54,
    barrierDismissible: true,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fadeAnimation = animation.drive(
        Tween(begin: 0.0, end: 1.0).chain(
          CurveTween(curve: Curves.easeOutCubic),
        ),
      );

      final scaleAnimation = animation.drive(
        Tween(begin: initialScale, end: 1.0).chain(
          CurveTween(curve: Curves.easeOutBack),
        ),
      );

      return FadeTransition(
        opacity: fadeAnimation,
        child: ScaleTransition(
          scale: scaleAnimation,
          child: child,
        ),
      );
    },
  );
}

/// Cross-fade transition between screens
class CrossFadePageTransition extends PageRouteBuilder {
  final Widget child;
  final RouteSettings? routeSettings;
  final Duration duration;

  CrossFadePageTransition({
    required this.child,
    this.routeSettings,
    this.duration = const Duration(milliseconds: 400),
  }) : super(
    pageBuilder: (context, animation, secondaryAnimation) => child,
    settings: routeSettings,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: FadeTransition(
          opacity: Tween<double>(begin: 1.0, end: 0.0).animate(secondaryAnimation),
          child: child,
        ),
      );
    },
  );
}

/// Blur fade transition with background blur effect
class BlurFadePageTransition extends PageRouteBuilder {
  final Widget child;
  final RouteSettings? routeSettings;
  final Duration duration;
  final double maxBlur;

  BlurFadePageTransition({
    required this.child,
    this.routeSettings,
    this.duration = const Duration(milliseconds: 300),
    this.maxBlur = 5.0,
  }) : super(
    pageBuilder: (context, animation, secondaryAnimation) => child,
    settings: routeSettings,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    opaque: false,
    barrierColor: Colors.transparent,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fadeAnimation = animation.drive(
        Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
      );

      final blurAnimation = animation.drive(
        Tween(begin: 0.0, end: maxBlur).chain(CurveTween(curve: Curves.easeInOut)),
      );

      return AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          return Stack(
            children: [
              // Blurred background
              if (animation.value > 0)
                BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: blurAnimation.value,
                    sigmaY: blurAnimation.value,
                  ),
                  child: Container(
                    color: Colors.black.withOpacity(0.3 * animation.value),
                  ),
                ),
              // Fade in content
              FadeTransition(
                opacity: fadeAnimation,
                child: child,
              ),
            ],
          );
        },
      );
    },
  );
}