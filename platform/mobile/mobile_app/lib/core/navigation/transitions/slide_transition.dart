import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

/// iOS-style slide transition that slides from right to left
class SlidePageTransition extends PageRouteBuilder {
  final Widget child;
  final RouteSettings? routeSettings;
  final Duration duration;
  final Curve curve;

  SlidePageTransition({
    required this.child,
    this.routeSettings,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
  }) : super(
    pageBuilder: (context, animation, secondaryAnimation) => child,
    settings: routeSettings,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Slide from right for primary animation
      const begin = Offset(1.0, 0.0);
      const end = Offset.zero;
      final slideTween = Tween(begin: begin, end: end);
      final slideAnimation = animation.drive(
        slideTween.chain(CurveTween(curve: curve)),
      );

      // Slide to left for secondary animation (when another page is pushed)
      const secondaryBegin = Offset.zero;
      const secondaryEnd = Offset(-0.3, 0.0);
      final secondarySlideTween = Tween(begin: secondaryBegin, end: secondaryEnd);
      final secondarySlideAnimation = secondaryAnimation.drive(
        secondarySlideTween.chain(CurveTween(curve: curve)),
      );

      return SlideTransition(
        position: slideAnimation,
        child: SlideTransition(
          position: secondarySlideAnimation,
          child: child,
        ),
      );
    },
  );
}

/// Cupertino-style modal slide transition (slides from bottom)
class ModalSlidePageTransition extends PageRouteBuilder {
  final Widget child;
  final RouteSettings? routeSettings;
  final Duration duration;
  final bool maintainState;

  ModalSlidePageTransition({
    required this.child,
    this.routeSettings,
    this.duration = const Duration(milliseconds: 300),
    this.maintainState = true,
  }) : super(
    pageBuilder: (context, animation, secondaryAnimation) => child,
    settings: routeSettings,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    maintainState: maintainState,
    opaque: false,
    barrierColor: Colors.black54,
    barrierDismissible: true,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Slide from bottom
      const begin = Offset(0.0, 1.0);
      const end = Offset.zero;
      final slideTween = Tween(begin: begin, end: end);
      final slideAnimation = animation.drive(
        slideTween.chain(CurveTween(curve: Curves.easeOutCubic)),
      );

      // Fade and scale background
      final fadeAnimation = animation.drive(
        Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
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

/// Custom slide transition with shadow
class ShadowSlidePageTransition extends PageRouteBuilder {
  final Widget child;
  final RouteSettings? routeSettings;
  final Color shadowColor;

  ShadowSlidePageTransition({
    required this.child,
    this.routeSettings,
    this.shadowColor = Colors.black26,
  }) : super(
    pageBuilder: (context, animation, secondaryAnimation) => child,
    settings: routeSettings,
    transitionDuration: const Duration(milliseconds: 350),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return Stack(
        children: [
          // Background shadow
          SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(-0.3, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: secondaryAnimation,
              curve: Curves.easeInOut,
            )),
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          // Main slide transition
          SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            )),
            child: Material(
              elevation: 8,
              shadowColor: shadowColor,
              child: child,
            ),
          ),
        ],
      );
    },
  );
}